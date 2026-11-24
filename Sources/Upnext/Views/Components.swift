import AppKit
import SwiftUI

extension View {
    /// The calendar-colored bar down the left of an event, or of a run of back-to-back events.
    /// `continuesAbove` squares its top so it meets the bar of the meeting above.
    func timelineBar(_ color: Color, continuesAbove: Bool = false) -> some View {
        padding(.leading, 5)
            .background(alignment: .leading) {
                TimelineBarShape(roundedTop: !continuesAbove, roundedBottom: true).fill(color).frame(width: 3)
            }
            .padding(.horizontal, 8)
    }
}

extension Color {
    /// One sRGB color, given as 0xRRGGBB, in light mode and another in dark mode.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            NSColor(hex: appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// A 3pt bar whose ends are rounded unless it joins another bar there.
struct TimelineBarShape: Shape {
    let roundedTop: Bool
    let roundedBottom: Bool

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: roundedTop ? 1.5 : 0,
            bottomLeadingRadius: roundedBottom ? 1.5 : 0,
            bottomTrailingRadius: roundedBottom ? 1.5 : 0,
            topTrailingRadius: roundedTop ? 1.5 : 0
        )
        .path(in: rect)
    }
}

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
    var height: CGFloat = 22
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
                .frame(width: 26, height: height)
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
