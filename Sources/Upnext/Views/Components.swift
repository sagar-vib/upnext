import AppKit
import SwiftUI

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

/// Rounded translucent surface used by the panel and the meeting alert.
struct PanelSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(VisualEffectBackground())
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
    }
}

struct IconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void
    // `State` as a plain stored property rather than `@State`: in the macOS 27 SDK `@State` is a
    // macro whose plugin ships only with Xcode, so `@State` breaks Command Line Tools builds.
    private let hovering = State(initialValue: false)

    var body: some View {
        Button {
            hovering.wrappedValue = false
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 26, height: 22)
                .background(hovering.wrappedValue ? Color.primary.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
        .onHover { hovering.wrappedValue = $0 }
    }
}

/// Full-width accent button used for "Join Google Meet".
struct JoinButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                Color.accentColor.opacity(configuration.isPressed ? 0.75 : 1),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .contentShape(Rectangle())
    }
}

/// Small accent capsule used for "Join" on hovered rows.
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.75 : 1), in: Capsule())
    }
}

struct ResponseIcon: View {
    let status: ResponseStatus

    var body: some View {
        switch status {
        case .accepted: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .declined: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .tentative: Image(systemName: "questionmark.circle.fill").foregroundStyle(.orange)
        case .pending, .none: Image(systemName: "circle").foregroundStyle(.secondary)
        }
    }
}

/// Join, copy link, email guests and open in calendar.
struct EventActionBar: View {
    let event: CalendarEvent
    let calendarApp: CalendarApp
    var showsJoin = false
    private let copied = State(initialValue: false) // see IconButton

    var body: some View {
        HStack(spacing: 2) {
            if showsJoin, let link = event.meeting {
                Button("Join \(link.service.name)") { EventActions.join(event) }
                    .buttonStyle(PillButtonStyle())
                    .padding(.trailing, 4)
            }
            if event.meeting != nil {
                IconButton(systemImage: copied.wrappedValue ? "checkmark" : "link", help: "Copy meeting link") {
                    EventActions.copyLink(event)
                    copied.wrappedValue = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copied.wrappedValue = false
                    }
                }
            }
            if !event.guestEmails.isEmpty {
                IconButton(systemImage: "envelope", help: "Email guests") { EventActions.emailGuests(event) }
            }
            IconButton(systemImage: "arrow.up.forward.square", help: "Open in \(calendarApp.title)") { EventActions.open(event) }
            Spacer(minLength: 0)
        }
    }
}
