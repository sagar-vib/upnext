import SwiftUI

struct PanelCommands {
    let openSettings: () -> Void
    let refresh: () -> Void
    let quit: () -> Void
}

/// Counts how often the dropdown has closed, so its list can start at the top next time.
@MainActor
final class PanelSession: ObservableObject {
    @Published private(set) var closes = 0

    func didClose() {
        closes += 1
    }
}

/// The dropdown under the menu bar item.
struct PanelView: View {
    @ObservedObject var store: CalendarStore
    @ObservedObject var clock: Clock
    @ObservedObject var prefs: Preferences
    @ObservedObject var session: PanelSession
    let commands: PanelCommands

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(now: clock.now, calendarApp: prefs.calendarApp, commands: commands)
            Divider()
            switch store.access {
            case .notDetermined:
                AccessPrompt(denied: false) { Task { await store.requestAccess() } }
            case .denied:
                AccessPrompt(denied: true) { EventActions.openCalendarPrivacySettings() }
            case .granted:
                let featured = store.featured(at: clock.now)
                Agenda(
                    featured: featured,
                    sections: store.sections(at: clock.now, after: featured),
                    now: clock.now,
                    joinShortcut: prefs.globalShortcuts ? HotKey.joinMeeting.display : nil,
                    scrollResetToken: session.closes
                )
            }
        }
        .frame(width: 340)
        .modifier(PanelSurface())
    }
}

private struct PanelHeader: View {
    let now: Date
    let calendarApp: CalendarApp
    let commands: PanelCommands

    var body: some View {
        HStack(spacing: 2) {
            VStack(alignment: .leading, spacing: 1) {
                Text(now.formatted(.dateTime.weekday(.wide)))
                    .font(.system(size: 13, weight: .semibold))
                Text(now.formatted(.dateTime.month(.wide).day()))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            IconButton(systemImage: "arrow.up.forward.app", help: "Open \(calendarApp.title)") {
                EventActions.openCalendarApp()
            }
            Menu {
                Button("Settings…", action: commands.openSettings)
                Button("Refresh", action: commands.refresh)
                Divider()
                Button("Quit Upnext", action: commands.quit)
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .frame(width: 26, height: 22)
            .help("More")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct Agenda: View {
    let featured: CalendarEvent?
    let sections: [DaySection]
    let now: Date
    let joinShortcut: String?
    let scrollResetToken: Int

    var body: some View {
        if let featured {
            FeaturedEventCard(event: featured, now: now, joinShortcut: joinShortcut)
                .padding(10)
            if !sections.isEmpty {
                Divider()
            }
        }
        if !sections.isEmpty {
            EventList(sections: sections, now: now, scrollResetToken: scrollResetToken)
        } else if featured == nil {
            EmptyAgenda()
        }
    }
}

/// The current or next event, with a big join button.
private struct FeaturedEventCard: View {
    let event: CalendarEvent
    let now: Date
    let joinShortcut: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(Fmt.relative(event, now: now))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(event.color)
                Spacer()
                Text(Fmt.range(event))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 8) {
                Capsule()
                    .fill(event.color)
                    .frame(width: 3)
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)

            if let link = event.meeting {
                Button { EventActions.join(event) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "video.fill")
                        Text("Join \(link.service.name)")
                        Spacer(minLength: 0)
                        if let joinShortcut {
                            Text(joinShortcut).opacity(0.7)
                        }
                    }
                }
                .buttonStyle(JoinButtonStyle())
            }

            if !event.guests.isEmpty || place != nil {
                VStack(alignment: .leading, spacing: 3) {
                    GuestList(guests: event.guests)
                    if let place {
                        DetailLine(systemImage: event.rooms.isEmpty ? "mappin.and.ellipse" : "building.2", text: place)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(event.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Meeting rooms, or the location when there are none.
    private var place: String? {
        event.rooms.isEmpty ? event.displayLocation : event.rooms.joined(separator: ", ")
    }
}

private struct EventList: View {
    let sections: [DaySection]
    let now: Date
    /// Changes whenever the list should jump back to its first day.
    let scrollResetToken: Int
    // Plain `State` storage, see IconButton.
    private let contentHeight = State(initialValue: CGFloat(0))
    private let expandedID = State<String?>(initialValue: nil)

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView(.vertical) {
                list
                    .id(Self.top)
                    .background(GeometryReader { proxy in
                        Color.clear.onChange(of: proxy.size.height, initial: true) { _, height in contentHeight.wrappedValue = height }
                    })
            }
            .onChange(of: scrollResetToken) { scroller.scrollTo(Self.top, anchor: .top) }
        }
        .frame(height: min(max(contentHeight.wrappedValue, 44), 440))
    }

    private static let top = "top"

    private var list: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                DayHeader(section: section, isFirst: index == 0)
                ForEach(section.items) { item in
                    switch item {
                    case .event(let event):
                        let rowID = "\(section.id.timeIntervalSince1970)|\(event.id)"
                        EventRow(
                            event: event,
                            now: now,
                            isExpanded: expandedID.wrappedValue == rowID,
                            onToggle: { expandedID.wrappedValue = expandedID.wrappedValue == rowID ? nil : rowID }
                        )
                    case .gap(_, let length):
                        GapRow(length: length)
                    }
                }
            }
        }
        .padding(8)
    }
}

/// Free time between two meetings, e.g. "30 min".
private struct GapRow: View {
    let length: TimeInterval

    var body: some View {
        Text(length > 0 ? Fmt.duration(length) : "Back to back")
            .font(.system(size: 10.5))
            .foregroundStyle(.tertiary)
            .padding(.leading, 19)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DayHeader: View {
    let section: DaySection
    let isFirst: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(section.title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(section.subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, isFirst ? 2 : 12)
        .padding(.bottom, 4)
    }
}

private struct EmptyAgenda: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("No upcoming events")
                .font(.system(size: 13, weight: .medium))
            Text("Enjoy the free time.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

private struct AccessPrompt: View {
    let denied: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: denied ? "calendar.badge.exclamationmark" : "calendar.badge.plus")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(denied ? "Calendar access is off" : "See your day from the menu bar")
                .font(.system(size: 13, weight: .semibold))
            Text(denied
                ? "Turn on Upnext in System Settings > Privacy & Security > Calendars."
                : "Upnext reads the calendars on this Mac, including Google, iCloud and Outlook accounts added in System Settings > Internet Accounts.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(denied ? "Open System Settings" : "Allow Calendar Access", action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}
