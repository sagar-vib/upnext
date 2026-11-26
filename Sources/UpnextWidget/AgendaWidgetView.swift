import AppKit
import SwiftUI
import UpnextShared
import WidgetKit

/// Small: the top meeting. Medium: the top meeting and the next few. Large: the dropdown's
/// day, timeline and all. Clicking anywhere but a Join button opens the dropdown.
struct AgendaWidgetView: View {
    let entry: AgendaEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(for: .widget) {
                Color(nsColor: .windowBackgroundColor)
            }
            .widgetURL(URL(string: "upnext://open"))
            // Light or Dark from Upnext's settings; System leaves it to macOS.
            .transformEnvironment(\.colorScheme) { scheme in
                switch entry.appearance {
                case "light": scheme = .light
                case "dark": scheme = .dark
                default: break
                }
            }
    }

    @ViewBuilder private var content: some View {
        if let content = entry.content {
            switch family {
            case .systemSmall:
                SmallAgenda(content: content)
            case .systemMedium:
                MediumAgenda(content: content)
            default:
                LargeAgenda(content: content)
            }
        } else {
            WidgetMessage(text: entry.message ?? "")
        }
    }
}

private struct SmallAgenda: View {
    let content: WidgetSnapshot.Entry

    var body: some View {
        if let featured = content.featured {
            FeaturedBlock(featured: featured, compact: true)
                .frame(maxHeight: .infinity, alignment: .top)
        } else {
            NothingLeft(content: content)
        }
    }
}

private struct MediumAgenda: View {
    let content: WidgetSnapshot.Entry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if let featured = content.featured {
                FeaturedBlock(featured: featured, compact: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                NothingLeft(content: content)
            }
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(content.laterEvents.prefix(3).enumerated()), id: \.offset) { _, event in
                    EventLine(event: event)
                        .timelineBar(Color(hex: event.color))
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private struct LargeAgenda: View {
    let content: WidgetSnapshot.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(content.weekday)
                    .font(.system(size: 13, weight: .semibold))
                Text(content.monthDay)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            if let featured = content.featured {
                FeaturedBlock(featured: featured, compact: false)
                    .padding(10)
                    .background(Color(hex: featured.event.color).opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            }
            if content.rows.isEmpty, content.featured == nil {
                Text("No more meetings")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            AgendaRows(rows: content.rows)
        }
        .clipped()
    }
}

/// The current or next meeting: when, what, and a Join button.
private struct FeaturedBlock: View {
    let featured: WidgetSnapshot.Featured
    /// Small and medium widgets: a shorter Join label.
    let compact: Bool

    var body: some View {
        let event = featured.event
        VStack(alignment: .leading, spacing: 6) {
            Text(featured.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: event.color))
                .lineLimit(1)
            HStack(alignment: .top, spacing: 8) {
                TimelineBarShape(roundedTop: true, roundedBottom: true)
                    .fill(Color(hex: event.color))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                    Text(event.time)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(compact ? 2 : 1)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let url = event.joinURL {
                Link(destination: url) {
                    Label(compact ? "Join" : "Join \(event.service ?? "meeting")", systemImage: "video.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 7))
                }
            }
        }
    }
}

/// The list under the top card, drawn like the dropdown's.
private struct AgendaRows: View {
    let rows: [WidgetSnapshot.Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                switch row {
                case .day(let title, let subtitle):
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 8)
                    .padding(.top, index == 0 ? 2 : 8)
                    .padding(.bottom, 3)
                case .run(let color, let continuesAbove, let entries):
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                            switch entry {
                            case .join(let text):
                                JoinLabel(text: text)
                            case .event(let event):
                                EventLine(event: event)
                            }
                        }
                    }
                    .timelineBar(Color(hex: color), continuesAbove: continuesAbove)
                case .gap(let text, let urgency):
                    GapRow(text: text, urgency: urgency)
                case .aside(let event):
                    EventLine(event: event, muted: true)
                        .timelineBar(Color(hex: event.color).opacity(0.35))
                        .padding(.top, 4)
                }
            }
        }
    }
}

/// One meeting in the list: title over its time, highlighted while it's on.
private struct EventLine: View {
    let event: WidgetSnapshot.Event
    /// Below the timeline: declined meetings and all-day events.
    var muted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(event.title)
                .font(.system(size: 12, weight: .medium))
                .strikethrough(event.isDeclined)
                .foregroundStyle(muted ? .secondary : .primary)
                .lineLimit(1)
            Text(event.time)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(event.isOngoing ? Color(hex: event.color).opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct NothingLeft: View {
    let content: WidgetSnapshot.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(content.weekday)
                .font(.system(size: 13, weight: .semibold))
            Text("No more meetings")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct WidgetMessage: View {
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension WidgetSnapshot.Entry {
    /// Meetings after the top one, in order, for the medium widget's list.
    var laterEvents: [WidgetSnapshot.Event] {
        rows.flatMap { row -> [WidgetSnapshot.Event] in
            switch row {
            case .run(_, _, let entries):
                entries.compactMap { entry -> WidgetSnapshot.Event? in
                    if case .event(let event) = entry { return event }
                    return nil
                }
            case .day, .gap, .aside:
                []
            }
        }
    }
}
