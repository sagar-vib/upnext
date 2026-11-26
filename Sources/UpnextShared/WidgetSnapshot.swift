import Foundation

/// What the desktop widget shows, written by the app and read by the widget extension.
/// The app works out each moment ahead of time (every minute for the next two hours, and
/// whenever a meeting starts or ends after that), so the widget only draws what it's given.
public struct WidgetSnapshot: Codable, Equatable {
    public var entries: [Entry]
    /// Shown instead of meetings, e.g. while Upnext has no calendar access.
    public var message: String?
    /// "light", "dark", or nil to follow the system.
    public var appearance: String?

    public init(entries: [Entry], message: String? = nil, appearance: String? = nil) {
        self.entries = entries
        self.message = message
        self.appearance = appearance
    }

    /// The widget's contents from `date` until the next entry.
    public struct Entry: Codable, Equatable {
        public var date: Date
        /// "Wednesday".
        public var weekday: String
        /// "November 25".
        public var monthDay: String
        public var featured: Featured?
        public var rows: [Row]

        public init(date: Date, weekday: String, monthDay: String, featured: Featured?, rows: [Row]) {
            self.date = date
            self.weekday = weekday
            self.monthDay = monthDay
            self.featured = featured
            self.rows = rows
        }
    }

    /// The meeting on the top card.
    public struct Featured: Codable, Equatable {
        public var event: Event
        /// "In 12 min", "Now · 18 min left".
        public var label: String

        public init(event: Event, label: String) {
            self.event = event
            self.label = label
        }
    }

    public struct Event: Codable, Equatable {
        public var title: String
        /// "10:00 AM - 10:30 AM (30 min)" or "All day".
        public var time: String
        /// The calendar's sRGB color as 0xRRGGBB.
        public var color: UInt32
        public var joinURL: URL?
        /// "Google Meet", for "Join Google Meet".
        public var service: String?
        public var isDeclined: Bool
        public var isOngoing: Bool

        public init(title: String, time: String, color: UInt32, joinURL: URL?, service: String?, isDeclined: Bool, isOngoing: Bool) {
            self.title = title
            self.time = time
            self.color = color
            self.joinURL = joinURL
            self.service = service
            self.isDeclined = isDeclined
            self.isOngoing = isOngoing
        }
    }

    /// One line of the list under the top card, in the dropdown's order.
    public enum Row: Codable, Equatable {
        /// A later day's header: "Tomorrow" with "Thu, Nov 26".
        case day(title: String, subtitle: String)
        /// Meetings sharing one bar, with labels where each joins the one before.
        case run(color: UInt32, continuesAbove: Bool, entries: [RunEntry])
        /// Free time between meetings: "20 min".
        case gap(text: String, urgency: GapUrgency)
        /// Below the timeline with a dimmed bar: declined meetings, then all-day events.
        case aside(Event)
    }

    public enum RunEntry: Codable, Equatable {
        /// "Back to back" or "Overlaps 10 min".
        case join(text: String)
        case event(Event)
    }
}

/// How much breathing room the time between two meetings leaves.
public enum GapUrgency: String, Codable {
    /// Under 15 minutes, including back to back and overlapping meetings.
    case tight
    /// 15 to 30 minutes.
    case short
    /// 30 minutes or more.
    case roomy

    /// Judged on whole minutes rounded up, as the gap is shown, so "15 min" is never tight.
    public init(_ length: TimeInterval) {
        let minutes = (length / 60).rounded(.up)
        self = minutes < 15 ? .tight : minutes < 30 ? .short : .roomy
    }
}

/// Where the app writes the snapshot and the widget reads it: Application Support in the
/// user's real home. The widget is sandboxed, so its home is its container; it reaches this
/// folder through a read-only exception entitlement.
public enum WidgetSnapshotFile {
    /// The widget's kind, for asking WidgetKit to reload it.
    public static let kind = "UpnextAgenda"

    public static var url: URL {
        realHome
            .appendingPathComponent("Library/Application Support/Upnext", isDirectory: true)
            .appendingPathComponent("Widget.json")
    }

    public static func read() -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// The user's home folder, not a sandbox container's.
    private static var realHome: URL {
        if let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }
}
