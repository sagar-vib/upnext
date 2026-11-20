import SwiftUI

@MainActor
struct EventRow: View {
    let event: CalendarEvent
    let now: Date
    let calendarApp: CalendarApp
    let isExpanded: Bool
    let onToggle: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(event.color)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(event.needsResponse ? .secondary : .primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                trailing
            }
            .fixedSize(horizontal: false, vertical: true)

            if isExpanded {
                EventDetails(event: event, calendarApp: calendarApp)
                    .padding(.leading, 11)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: onToggle)
    }

    private var subtitle: String {
        switch event.myStatus {
        case .pending: "\(Fmt.range(event)) · Not responded"
        case .tentative: "\(Fmt.range(event)) · Maybe"
        default: Fmt.range(event)
        }
    }

    private var background: Color {
        if event.isOngoing(at: now) { return event.color.opacity(hovering ? 0.22 : 0.14) }
        return hovering ? Color.primary.opacity(0.07) : Color.clear
    }

    @ViewBuilder private var trailing: some View {
        if hovering, event.meeting != nil {
            Button("Join") {
                hovering = false
                EventActions.join(event)
            }
            .buttonStyle(PillButtonStyle())
        } else if event.isOngoing(at: now) {
            Text("Now")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(event.color)
        } else if let link = event.meeting {
            Image(systemName: "video")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .help(link.service.name)
        }
    }
}

/// Shown under a row when it's clicked: where, who, notes and actions.
struct EventDetails: View {
    let event: CalendarEvent
    let calendarApp: CalendarApp

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let location = event.displayLocation {
                DetailLine(systemImage: "mappin.and.ellipse", text: location)
            }
            if !event.rooms.isEmpty {
                DetailLine(systemImage: "building.2", text: event.rooms.joined(separator: ", "))
            }
            if !event.guests.isEmpty {
                DetailLine(systemImage: "person.2", text: Fmt.guestSummary(event.guests))
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(event.guests.prefix(8).enumerated()), id: \.offset) { _, guest in
                        HStack(spacing: 6) {
                            ResponseIcon(status: guest.status).font(.system(size: 10))
                            Text(guest.name).font(.system(size: 11)).lineLimit(1)
                        }
                    }
                    if event.guests.count > 8 {
                        Text("and \(event.guests.count - 8) more")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 20)
            }
            if let notes = event.notesSummary {
                Text(notes)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            EventActionBar(event: event, calendarApp: calendarApp, showsJoin: true)
        }
    }
}

private struct DetailLine: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(text)
                .font(.system(size: 11))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
