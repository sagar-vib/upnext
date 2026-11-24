import AppKit
import Combine
import SwiftUI

/// Pops up a floating "Join" card shortly before each meeting, like Notion
/// Calendar's upcoming meeting notification. Shows over full screen apps too.
@MainActor
final class MeetingAlertController: ObservableObject {
    @Published private(set) var items: [CalendarEvent] = []

    private let store: CalendarStore
    private let prefs: Preferences
    private let panel: HostingPanel
    private var alerted = Set<String>()
    private var cancellables = Set<AnyCancellable>()

    init(store: CalendarStore, clock: Clock, prefs: Preferences) {
        self.store = store
        self.prefs = prefs
        self.panel = HostingPanel(closesOnOutsideClick: false)

        panel.placement = { size in
            let frame = NSScreen.main?.visibleFrame ?? .zero
            return NSPoint(x: frame.maxX - size.width - 12, y: frame.maxY - size.height - 12)
        }
        panel.setContent(MeetingAlertView(controller: self, clock: clock))

        clock.$now
            .sink { [weak self] now in self?.check(at: now) }
            .store(in: &cancellables)
    }

    func join(_ event: CalendarEvent) {
        EventActions.join(event)
        dismiss(event)
    }

    func dismiss(_ event: CalendarEvent) {
        items.removeAll { $0.id == event.id }
        if items.isEmpty {
            panel.close()
        }
    }

    private func check(at now: Date) {
        if let lead = prefs.alertLead.seconds {
            let due = store.events.filter { event in
                event.isMeeting
                    && store.isActive(event, at: now)
                    && !alerted.contains(event.id)
                    && now >= event.start.addingTimeInterval(-lead)
                    && now < min(event.end, event.start.addingTimeInterval(5 * 60))
            }
            if !due.isEmpty {
                due.forEach { alerted.insert($0.id) }
                items.append(contentsOf: due)
                AlertSound.play(prefs.alertSound)
                panel.show(makeKey: false)
            }
        }

        // Ended, marked done, or showing for 10 minutes.
        let expired = items.filter { !store.isActive($0, at: now) || now >= $0.start.addingTimeInterval(10 * 60) }
        if !expired.isEmpty {
            expired.forEach { dismiss($0) }
        }
    }
}

private struct MeetingAlertView: View {
    @ObservedObject var controller: MeetingAlertController
    @ObservedObject var clock: Clock

    var body: some View {
        VStack(spacing: 8) {
            ForEach(controller.items) { event in
                MeetingAlertCard(
                    event: event,
                    now: clock.now,
                    onJoin: { controller.join(event) },
                    onOpen: { EventActions.open(event); controller.dismiss(event) },
                    onDismiss: { controller.dismiss(event) }
                )
            }
        }
        .frame(width: 320)
        .padding(6)
    }
}

private struct MeetingAlertCard: View {
    let event: CalendarEvent
    let now: Date
    let onJoin: () -> Void
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Capsule()
                    .fill(event.color)
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                    Text("\(Fmt.alertStatus(event, now: now)) · \(Fmt.range(event))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 20, height: 20)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Dismiss")
            }
            .fixedSize(horizontal: false, vertical: true)

            if let link = event.meeting {
                Button(action: onJoin) {
                    Label("Join \(link.service.name)", systemImage: "video.fill")
                }
                .buttonStyle(JoinButtonStyle())
            } else {
                Button("Open event", action: onOpen)
                    .buttonStyle(JoinButtonStyle())
            }
        }
        .padding(12)
        .modifier(PanelSurface())
    }
}
