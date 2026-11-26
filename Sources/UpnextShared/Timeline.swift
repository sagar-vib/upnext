import AppKit
import SwiftUI

// The timeline pieces the dropdown and the desktop widget both draw.

public extension View {
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

/// A 3pt bar whose ends are rounded unless it joins another bar there.
public struct TimelineBarShape: Shape {
    let roundedTop: Bool
    let roundedBottom: Bool

    public init(roundedTop: Bool, roundedBottom: Bool) {
        self.roundedTop = roundedTop
        self.roundedBottom = roundedBottom
    }

    public func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: roundedTop ? 1.5 : 0,
            bottomLeadingRadius: roundedBottom ? 1.5 : 0,
            bottomTrailingRadius: roundedBottom ? 1.5 : 0,
            topTrailingRadius: roundedTop ? 1.5 : 0
        )
        .path(in: rect)
    }
}

/// Free time between two meetings, e.g. "30 min", colored by how much room it leaves, with a
/// dotted line in the bar column joining the meetings above and below.
public struct GapRow: View {
    let text: String
    let urgency: GapUrgency

    public init(text: String, urgency: GapUrgency) {
        self.text = text
        self.urgency = urgency
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 10.5))
            .foregroundStyle(urgency.color)
            .padding(.leading, 19)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .leading) {
                // Centered under the 3pt bars, reaching across the 1pt list spacing to touch them.
                VerticalLine()
                    .stroke(urgency.color, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0, 4]))
                    .frame(width: 2)
                    .padding(.vertical, -1)
                    .padding(.leading, 8.5)
            }
    }
}

/// Inside a run's bar, where a meeting joins the one before: "Back to back" or "Overlaps 15 min".
/// No time between them, so it's in the tight color.
public struct JoinLabel: View {
    let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 10.5))
            .foregroundStyle(GapUrgency.tight.color)
            .padding(.leading, 6)
            .padding(.top, 4)
            .padding(.bottom, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
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

public extension GapUrgency {
    // Apple's higher-contrast system colors, so 10.5pt text stays readable.
    private static let tightColor = Color.adaptive(light: 0xD70015, dark: 0xFF6961)
    private static let shortColor = Color.adaptive(light: 0xA16207, dark: 0xF2C14E)
    private static let roomyColor = Color.adaptive(light: 0x1E7A35, dark: 0x3DD068)

    var color: Color {
        switch self {
        case .tight: Self.tightColor
        case .short: Self.shortColor
        case .roomy: Self.roomyColor
        }
    }
}

public extension Color {
    /// An sRGB color given as 0xRRGGBB.
    init(hex: UInt32) {
        self.init(nsColor: NSColor(hex: hex))
    }

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
