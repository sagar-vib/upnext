import SwiftUI
import UpnextShared
import WidgetKit

@main
struct UpnextWidgets: WidgetBundle {
    var body: some Widget {
        AgendaWidget()
    }
}

struct AgendaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshotFile.kind, provider: AgendaProvider()) { entry in
            AgendaWidgetView(entry: entry)
        }
        .configurationDisplayName("Upnext")
        .description("Your current or next meeting, and the rest of the day.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct AgendaEntry: TimelineEntry {
    let date: Date
    let content: WidgetSnapshot.Entry?
    /// Shown instead of meetings.
    let message: String?
    let appearance: String?
}

/// Steps through the moments the app worked out. The app rewrites the file as time passes
/// and asks for a reload when meetings change; rereading hourly picks up the rest.
struct AgendaProvider: TimelineProvider {
    /// Without the app rewriting it, the snapshot's minute-by-minute part runs out.
    private static let staleAfter: TimeInterval = 3 * 3600

    func placeholder(in context: Context) -> AgendaEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (AgendaEntry) -> Void) {
        completion(context.isPreview ? .sample : Self.entries(at: Date())[0])
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AgendaEntry>) -> Void) {
        let now = Date()
        completion(Timeline(entries: Self.entries(at: now), policy: .after(now.addingTimeInterval(3600))))
    }

    /// The snapshot's moments from now on, never empty.
    static func entries(at now: Date) -> [AgendaEntry] {
        guard let snapshot = WidgetSnapshotFile.read() else {
            return [AgendaEntry(date: now, content: nil, message: "Open Upnext to show your meetings here.", appearance: nil)]
        }
        if let message = snapshot.message {
            return [AgendaEntry(date: now, content: nil, message: message, appearance: snapshot.appearance)]
        }
        guard let first = snapshot.entries.first, now.timeIntervalSince(first.date) < staleAfter,
              let current = snapshot.entries.lastIndex(where: { $0.date <= now }) else {
            return [AgendaEntry(date: now, content: nil, message: "Open Upnext to update your meetings.", appearance: snapshot.appearance)]
        }
        return snapshot.entries[current...].enumerated().map { index, moment in
            AgendaEntry(date: index == 0 ? now : moment.date, content: moment, message: nil, appearance: snapshot.appearance)
        }
    }
}

extension AgendaEntry {
    /// For the widget gallery and while the widget loads.
    static let sample: AgendaEntry = {
        func event(_ title: String, _ time: String, color: UInt32 = 0x007AFF, link: Bool = true, ongoing: Bool = false) -> WidgetSnapshot.Event {
            WidgetSnapshot.Event(
                title: title,
                time: time,
                color: color,
                joinURL: link ? URL(string: "https://meet.google.com") : nil,
                service: link ? "Google Meet" : nil,
                isDeclined: false,
                isOngoing: ongoing
            )
        }
        let content = WidgetSnapshot.Entry(
            date: Date(),
            weekday: "Wednesday",
            monthDay: "November 25",
            featured: WidgetSnapshot.Featured(event: event("Standup", "10:00 AM - 10:30 AM (30 min)", ongoing: true), label: "Now · 18 min left"),
            rows: [
                .gap(text: "10 min", urgency: .tight),
                .run(color: 0x007AFF, continuesAbove: false, entries: [
                    .event(event("Pipeline review", "10:40 AM - 11:10 AM (30 min)")),
                    .join(text: "Back to back"),
                    .event(event("Client onboarding", "11:10 AM - 11:40 AM (30 min)")),
                ]),
                .gap(text: "20 min", urgency: .short),
                .run(color: 0x007AFF, continuesAbove: false, entries: [.event(event("Ops check-in", "12:00 PM - 12:15 PM (15 min)"))]),
                .gap(text: "1 hr 45 min", urgency: .roomy),
                .run(color: 0x007AFF, continuesAbove: false, entries: [.event(event("Sprint planning", "2:00 PM - 3:00 PM (1 hr)"))]),
            ]
        )
        return AgendaEntry(date: Date(), content: content, message: nil, appearance: nil)
    }()
}
