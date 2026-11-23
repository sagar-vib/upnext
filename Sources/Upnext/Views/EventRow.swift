import SwiftUI

@MainActor
struct EventRow: View {
    let event: CalendarEvent
    let now: Date
    let isExpanded: Bool
    let onToggle: () -> Void
    private let hovering = State(initialValue: false) // see IconButton

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(event.isAllDay ? .secondary : .primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                trailing
            }

            if isExpanded {
                EventDetails(event: event)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering.wrappedValue = $0 }
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
        if event.isOngoing(at: now) { return event.color.opacity(hovering.wrappedValue ? 0.22 : 0.14) }
        return hovering.wrappedValue ? Color.primary.opacity(0.07) : Color.clear
    }

    @ViewBuilder private var trailing: some View {
        if hovering.wrappedValue, event.meeting != nil {
            Button("Join") {
                hovering.wrappedValue = false
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

/// Shown under a row when it's clicked: where, who and notes.
struct EventDetails: View {
    let event: CalendarEvent

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
                GuestList(guests: event.guests)
            }
            if let notes = event.notesSummary {
                Text(notes)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Each guest's reply and email, in the same icon column as DetailLine so the icons line up.
struct GuestList: View {
    let guests: [Attendee]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(guests.prefix(8).enumerated()), id: \.offset) { _, guest in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    ResponseIcon(status: guest.status)
                        .font(.system(size: 10))
                        .frame(width: 14)
                    Text(guest.email ?? guest.name)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
            }
            if guests.count > 8 {
                Text("and \(guests.count - 8) more")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }
        }
    }
}

struct DetailLine: View {
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
