import AppKit
import Combine
import EventKit
import SwiftUI

enum CalendarAccess {
    case notDetermined, granted, denied
}

struct DaySection: Identifiable {
    let id: Date
    /// Nil for today, which the panel's own header already names.
    let title: String?
    let subtitle: String
    let events: [CalendarEvent]
    /// End of the top card's meeting when it's on this day, so the first gap counts from it.
    let startsAfter: Date?

    /// The day as a timeline: back-to-back or overlapping meetings share one bar, real free
    /// time between them gets a gap row, and all-day events go at the bottom.
    var items: [AgendaItem] {
        var items: [AgendaItem] = []
        var run: [CalendarEvent] = []
        var busyUntil = startsAfter
        for event in events where !event.isAllDay {
            let continuesRun = !run.isEmpty && busyUntil.map { event.start <= $0 } == true
            if !continuesRun {
                if !run.isEmpty {
                    items.append(.meetings(run))
                    run = []
                }
                if let busyUntil, event.start >= busyUntil {
                    items.append(.gap(id: "gap|\(event.id)", length: event.start.timeIntervalSince(busyUntil)))
                }
            }
            run.append(event)
            busyUntil = max(busyUntil ?? event.end, event.end)
        }
        if !run.isEmpty {
            items.append(.meetings(run))
        }
        return items + events.filter(\.isAllDay).map(AgendaItem.allDay)
    }
}

enum AgendaItem: Identifiable {
    /// One meeting, or a run of back-to-back or overlapping meetings sharing one bar.
    case meetings([CalendarEvent])
    /// Free time before the next meeting; zero only right after the top card's meeting.
    case gap(id: String, length: TimeInterval)
    case allDay(CalendarEvent)

    var id: String {
        switch self {
        case .meetings(let events): "meetings|\(events.first?.id ?? "")"
        case .gap(let id, _): id
        case .allDay(let event): "allday|\(event.id)"
        }
    }
}

/// Reads events from every calendar account on this Mac (Google, iCloud, Exchange...)
/// and keeps them current as calendars, the day, or the preferences change.
@MainActor
final class CalendarStore: ObservableObject {
    @Published private(set) var access: CalendarAccess
    @Published private(set) var calendarGroups: [CalendarGroup] = []
    @Published private(set) var events: [CalendarEvent] = []

    private let eventStore = EKEventStore()
    private let prefs: Preferences
    private var cancellables = Set<AnyCancellable>()

    init(prefs: Preferences) {
        self.prefs = prefs
        self.access = Self.currentAccess()

        let center = NotificationCenter.default
        Publishers.Merge4(
            center.publisher(for: .EKEventStoreChanged, object: eventStore).map { _ in () },
            center.publisher(for: .NSCalendarDayChanged).map { _ in () },
            NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification).map { _ in () },
            prefs.objectWillChange.map { _ in () }
        )
        .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
        .sink { [weak self] in self?.reload() }
        .store(in: &cancellables)

        reload()
    }

    func requestAccess() async {
        _ = try? await eventStore.requestFullAccessToEvents()
        reload()
    }

    func reload() {
        access = Self.currentAccess()
        guard access == .granted else {
            calendarGroups = []
            events = []
            return
        }

        let calendars = eventStore.calendars(for: .event)
        calendarGroups = Dictionary(grouping: calendars) { $0.source?.title ?? "Other" }
            .map { account, members in
                CalendarGroup(
                    id: account,
                    calendars: members
                        .map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title, color: Color(nsColor: $0.color ?? .systemBlue)) }
                        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                )
            }
            .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }

        let visible = calendars.filter { !prefs.hiddenCalendarIDs.contains($0.calendarIdentifier) }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        guard !visible.isEmpty,
              let end = Calendar.current.date(byAdding: .day, value: prefs.dayRange.rawValue, to: startOfToday) else {
            events = []
            return
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfToday, end: end, calendars: visible)
        var seen = Set<String>()
        events = eventStore.events(matching: predicate)
            .map { CalendarEvent($0) }
            .filter { include($0) }
            .sorted(by: Self.chronological)
            .filter { seen.insert($0.dedupeKey).inserted }
    }

    /// The event the menu bar and the top card focus on: the meeting in progress,
    /// or the next one if it starts within 10 minutes or nothing is in progress.
    func featured(at now: Date) -> CalendarEvent? {
        Self.focus(events.filter { !$0.isAllDay && $0.end > now }, at: now)
    }

    /// The meeting the join shortcut opens: the featured event when it has a link,
    /// otherwise the nearest event with a link that starts within 30 minutes.
    func joinable(at now: Date) -> CalendarEvent? {
        if let featured = featured(at: now), featured.meeting != nil {
            return featured
        }
        let candidates = events.filter {
            !$0.isAllDay && $0.meeting != nil && $0.end > now && $0.start.timeIntervalSince(now) <= 30 * 60
        }
        return Self.focus(candidates, at: now)
    }

    /// Remaining events grouped by day, leaving out the one on the top card and days with
    /// nothing on. Today has no header; a later first day is "Upcoming", naming tomorrow.
    func sections(at now: Date, after featured: CalendarEvent?) -> [DaySection] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        var sections: [DaySection] = []
        for offset in 0..<prefs.dayRange.rawValue {
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: today),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            let onDay = events.filter { $0.id != featured?.id && $0.start < dayEnd && $0.end > dayStart && $0.end > now }
            guard !onDay.isEmpty else { continue }
            let isFirst = sections.isEmpty
            let featuredOnDay = featured.map { $0.start < dayEnd && $0.end > dayStart } ?? false
            sections.append(DaySection(
                id: dayStart,
                title: isFirst ? (offset == 0 ? nil : "Upcoming") : Fmt.dayTitle(dayStart),
                subtitle: isFirst && offset == 1 ? "Tomorrow · \(Fmt.shortDate(dayStart))" : Fmt.shortDate(dayStart),
                events: onDay,
                startsAfter: featuredOnDay ? featured?.end : nil
            ))
        }
        return sections
    }

    private func include(_ event: CalendarEvent) -> Bool {
        if event.isCanceled || event.myStatus == .declined { return false }
        if event.isAllDay && !prefs.includeAllDay { return false }
        if event.guests.isEmpty && !prefs.includeWithoutGuests { return false }
        if event.meeting == nil && event.location == nil && !prefs.includeWithoutLocation { return false }
        return true
    }

    nonisolated private static func focus(_ candidates: [CalendarEvent], at now: Date) -> CalendarEvent? {
        let ongoing = candidates.filter { $0.start <= now }.max { $0.start < $1.start }
        let next = candidates.first { $0.start > now }
        guard let ongoing else { return next }
        guard let next, next.start.timeIntervalSince(now) <= 10 * 60 else { return ongoing }
        return next
    }

    /// Start time, all-day first, then title. Copies with a meeting link sort first so de-duplication keeps them.
    nonisolated private static func chronological(_ a: CalendarEvent, _ b: CalendarEvent) -> Bool {
        if a.start != b.start { return a.start < b.start }
        if a.isAllDay != b.isAllDay { return a.isAllDay }
        if a.title != b.title { return a.title < b.title }
        return a.meeting != nil && b.meeting == nil
    }

    private static func currentAccess() -> CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }
}
