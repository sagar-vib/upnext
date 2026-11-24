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
            PanelHeader(
                day: prefs.workDay.start(containing: clock.now),
                calendarApp: prefs.calendarApp,
                doneEvents: store.doneEvents(at: clock.now),
                restore: { store.restore($0) },
                commands: commands
            )
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
                    workDay: prefs.workDay,
                    joinShortcut: prefs.globalShortcuts ? HotKey.joinMeeting.display : nil,
                    scrollResetToken: session.closes,
                    markDone: { store.markDone($0) }
                )
            }
        }
        .frame(width: 340)
        .modifier(PanelSurface())
    }
}

private struct PanelHeader: View {
    let day: Date
    let calendarApp: CalendarApp
    /// Meetings marked done that are still on, offered in the menu to undo.
    let doneEvents: [CalendarEvent]
    let restore: (CalendarEvent) -> Void
    let commands: PanelCommands

    var body: some View {
        HStack(spacing: 2) {
            VStack(alignment: .leading, spacing: 1) {
                Text(day.formatted(.dateTime.weekday(.wide)))
                    .font(.system(size: 13, weight: .semibold))
                Text(day.formatted(.dateTime.month(.wide).day()))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            IconButton(systemImage: "arrow.up.forward.app", help: "Open \(calendarApp.title)") {
                EventActions.openCalendarApp()
            }
            Menu {
                ForEach(doneEvents) { event in
                    Button("Restore \u{201C}\(Fmt.truncate(event.title, to: 40))\u{201D}") { restore(event) }
                }
                if !doneEvents.isEmpty {
                    Divider()
                }
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
    let workDay: WorkDay
    let joinShortcut: String?
    let scrollResetToken: Int
    let markDone: (CalendarEvent) -> Void

    var body: some View {
        if let featured {
            FeaturedSection(
                event: featured,
                now: now,
                workDay: workDay,
                joinShortcut: joinShortcut,
                continuesIntoList: sections.first?.joinsTopMeeting == true,
                markDone: { markDone(featured) }
            )
            .id(featured.id)
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

/// The current or next meeting, filling the band between the dividers. Clicking it shows or
/// hides the guests. When the next meeting follows straight on, its bar runs down to the list
/// and the Join button moves in beside it. While the meeting is on, a checkmark ends it early.
private struct FeaturedSection: View {
    let event: CalendarEvent
    let now: Date
    let workDay: WorkDay
    let joinShortcut: String?
    let continuesIntoList: Bool
    let markDone: () -> Void
    // Plain `State` storage, see IconButton.
    private let showsGuests = State(initialValue: false)
    private let hovering = State(initialValue: false)

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(Fmt.relative(event, now: now, workDay: workDay))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(event.color)
                Spacer()
                Text(Fmt.range(event))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if event.isOngoing(at: now) {
                    IconButton(systemImage: "checkmark.circle", help: "Mark as done (⌘D)", height: 18, action: markDone)
                        .padding(.vertical, -2)
                }
            }

            if continuesIntoList {
                VStack(alignment: .leading, spacing: 9) {
                    title
                    joinButton
                    details
                }
                .padding(.leading, 11)
                .padding(.bottom, 14)
                .background(alignment: .leading) {
                    TimelineBarShape(roundedTop: true, roundedBottom: false).fill(event.color).frame(width: 3)
                }
            } else {
                HStack(alignment: .top, spacing: 8) {
                    TimelineBarShape(roundedTop: true, roundedBottom: true).fill(event.color).frame(width: 3)
                    title
                }
                .fixedSize(horizontal: false, vertical: true)
                joinButton
                details
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, continuesIntoList ? 0 : 14)
        .background(event.color.opacity(hovering.wrappedValue && !event.guests.isEmpty ? 0.15 : 0.1))
        .contentShape(Rectangle())
        .onHover { hovering.wrappedValue = $0 }
        .onTapGesture {
            if !event.guests.isEmpty {
                showsGuests.wrappedValue = !showsGuests.wrappedValue
            }
        }
    }

    private var title: some View {
        Text(event.title)
            .font(.system(size: 14, weight: .semibold))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var joinButton: some View {
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
    }

    @ViewBuilder private var details: some View {
        let guests = showsGuests.wrappedValue ? event.guests : []
        if !guests.isEmpty || place != nil {
            VStack(alignment: .leading, spacing: 3) {
                if !guests.isEmpty {
                    GuestList(guests: guests)
                }
                if let place {
                    DetailLine(systemImage: event.rooms.isEmpty ? "mappin.and.ellipse" : "building.2", text: place)
                }
            }
            .foregroundStyle(.secondary)
        }
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
                if let title = section.title {
                    DayHeader(title: title, subtitle: section.subtitle, isFirst: index == 0)
                }
                ForEach(section.items) { item in
                    switch item {
                    case .run(let run):
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(run.entries) { entry in
                                switch entry {
                                case .join(_, let overlap):
                                    JoinLabel(overlap: overlap)
                                case .event(let event):
                                    row(event, in: section)
                                }
                            }
                        }
                        .timelineBar(run.color, continuesAbove: run.continuesAbove)
                    case .gap(_, let length):
                        GapRow(length: length)
                    case .aside(let event):
                        row(event, in: section)
                            .timelineBar(event.color.opacity(0.35))
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        // A bar continuing from the top section starts right at the divider.
        .padding(.top, sections.first?.joinsTopMeeting == true ? 0 : 8)
    }

    private func row(_ event: CalendarEvent, in section: DaySection) -> EventRow {
        let rowID = "\(section.id.timeIntervalSince1970)|\(event.id)"
        return EventRow(
            event: event,
            now: now,
            isExpanded: expandedID.wrappedValue == rowID,
            onToggle: { expandedID.wrappedValue = expandedID.wrappedValue == rowID ? nil : rowID }
        )
    }
}

/// Free time between two meetings, e.g. "30 min", colored by how much room it leaves, with a
/// dotted line in the bar column joining the meetings above and below.
private struct GapRow: View {
    let length: TimeInterval

    var body: some View {
        let color = GapUrgency(length).color
        Text(Fmt.duration(length))
            .font(.system(size: 10.5))
            .foregroundStyle(color)
            .padding(.leading, 19)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .leading) {
                // Centered under the 3pt bars, reaching across the 1pt list spacing to touch them.
                VerticalLine()
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0, 4]))
                    .frame(width: 2)
                    .padding(.vertical, -1)
                    .padding(.leading, 8.5)
            }
    }
}

private struct VerticalLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
    }
}

private extension GapUrgency {
    // Apple's higher-contrast system colors, so 10.5pt text stays readable on the panel.
    static let tightColor = Color.adaptive(light: 0xD70015, dark: 0xFF6961)
    static let shortColor = Color.adaptive(light: 0xA16207, dark: 0xF2C14E)
    static let roomyColor = Color.adaptive(light: 0x1E7A35, dark: 0x3DD068)

    var color: Color {
        switch self {
        case .tight: Self.tightColor
        case .short: Self.shortColor
        case .roomy: Self.roomyColor
        }
    }
}

/// Inside a run's bar, where a meeting joins the one before: "Back to back" or "Overlaps 15 min".
/// No time between them, so it's in the tight color.
private struct JoinLabel: View {
    let overlap: TimeInterval

    var body: some View {
        Text(overlap > 0 ? "Overlaps \(Fmt.duration(overlap))" : "Back to back")
            .font(.system(size: 10.5))
            .foregroundStyle(GapUrgency.tight.color)
            .padding(.leading, 6)
            .padding(.top, 4)
            .padding(.bottom, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DayHeader: View {
    let title: String
    let subtitle: String
    let isFirst: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(subtitle)
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
