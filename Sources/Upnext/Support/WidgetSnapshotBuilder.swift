import Foundation
import UpnextShared

/// Works out what the desktop widget shows at each moment ahead, from the same agenda the
/// dropdown uses, so the widget can step through it without the app.
@MainActor
enum WidgetSnapshotBuilder {
    /// Every minute for this long, so countdowns keep ticking between the widget's reloads.
    static let minuteSpan: TimeInterval = 2 * 3600
    /// The large widget shows about this many lines; more would only grow the file.
    static let rowLimit = 16

    static func snapshot(store: CalendarStore, prefs: Preferences, now: Date) -> WidgetSnapshot {
        let appearance: String? = switch prefs.appearance {
        case .light: "light"
        case .dark: "dark"
        case .system: nil
        }
        guard store.access == .granted else {
            return WidgetSnapshot(entries: [], message: "Open Upnext and allow calendar access.", appearance: appearance)
        }
        let entries = moments(after: now, events: store.events, workDay: prefs.workDay).map {
            entry(at: $0, store: store, workDay: prefs.workDay)
        }
        return WidgetSnapshot(entries: entries, appearance: appearance)
    }

    /// True when the widget would look different at some moment both snapshots cover, or the
    /// new one shows something the old one never did. Rolling the minutes forward alone isn't
    /// a change, which keeps reloads within WidgetKit's daily budget.
    static func changed(from old: WidgetSnapshot?, to new: WidgetSnapshot) -> Bool {
        guard let old, old.message == new.message, old.appearance == new.appearance else { return true }
        let oldEntries = Dictionary(old.entries.map { ($0.date, $0) }, uniquingKeysWith: { first, _ in first })
        return new.entries.contains { entry in
            oldEntries[entry.date].map { $0 != entry } ?? false
        }
    }

    /// The start of this minute, each minute after it for `minuteSpan`, and every later moment
    /// the widget changes: a meeting taking the top card 10 minutes before it starts, starting,
    /// ending, and each new day.
    static func moments(after now: Date, events: [CalendarEvent], workDay: WorkDay) -> [Date] {
        let first = Date(timeIntervalSinceReferenceDate: (now.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60)
        var dates = Set(stride(from: 0, to: minuteSpan, by: 60).map { first.addingTimeInterval($0) })
        var last = first.addingTimeInterval(minuteSpan)
        for event in events where !event.isAllDay {
            dates.formUnion([event.start.addingTimeInterval(-10 * 60), event.start, event.end])
            last = max(last, event.end)
        }
        var day = workDay.start(containing: first)
        while let next = Calendar.current.date(byAdding: .day, value: 1, to: day), next <= last {
            dates.insert(next)
            day = next
        }
        return dates.filter { $0 >= first }.sorted()
    }

    static func entry(at date: Date, store: CalendarStore, workDay: WorkDay) -> WidgetSnapshot.Entry {
        let featured = store.featured(at: date)
        var rows: [WidgetSnapshot.Row] = []
        for section in store.sections(at: date, after: featured) {
            if let title = section.title {
                rows.append(.day(title: title, subtitle: section.subtitle))
            }
            rows += section.items.map { row($0, at: date) }
        }
        let day = workDay.start(containing: date)
        return WidgetSnapshot.Entry(
            date: date,
            weekday: Fmt.weekday(day),
            monthDay: Fmt.monthDay(day),
            featured: featured.map {
                WidgetSnapshot.Featured(event: event($0, at: date), label: Fmt.relative($0, now: date, workDay: workDay))
            },
            rows: Array(rows.prefix(rowLimit))
        )
    }

    private static func row(_ item: AgendaItem, at date: Date) -> WidgetSnapshot.Row {
        switch item {
        case .run(let run):
            let entries: [WidgetSnapshot.RunEntry] = run.entries.map { entry in
                switch entry {
                case .join(_, let overlap): .join(text: Fmt.joinLabel(overlap: overlap))
                case .event(let calendarEvent): .event(event(calendarEvent, at: date))
                }
            }
            let color = run.entries.lazy.compactMap { entry -> UInt32? in
                if case .event(let calendarEvent) = entry { return calendarEvent.colorHex }
                return nil
            }.first ?? 0x007AFF
            return .run(color: color, continuesAbove: run.continuesAbove, entries: entries)
        case .gap(_, let length):
            return .gap(text: Fmt.duration(length), urgency: GapUrgency(length))
        case .aside(let calendarEvent):
            return .aside(event(calendarEvent, at: date))
        }
    }

    private static func event(_ event: CalendarEvent, at date: Date) -> WidgetSnapshot.Event {
        WidgetSnapshot.Event(
            title: event.title,
            time: Fmt.range(event),
            color: event.colorHex,
            joinURL: event.meeting?.launchURL(accountEmail: event.accountEmail),
            service: event.meeting?.service.name,
            isDeclined: event.myStatus == .declined,
            isOngoing: event.isBusy && event.isOngoing(at: date)
        )
    }
}
