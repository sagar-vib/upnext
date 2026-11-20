import Combine
import Foundation

enum PreviewLead: Int, CaseIterable, Identifiable {
    case never = 0, five = 5, fifteen = 15, thirty = 30, hour = 60, twoHours = 120, fourHours = 240, always = -1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .never: "Never"
        case .always: "Always"
        case .hour: "1 hour before"
        case .twoHours: "2 hours before"
        case .fourHours: "4 hours before"
        default: "\(rawValue) minutes before"
        }
    }

    func includes(_ timeUntilStart: TimeInterval) -> Bool {
        switch self {
        case .never: false
        case .always: true
        default: timeUntilStart <= TimeInterval(rawValue * 60)
        }
    }
}

enum DayRange: Int, CaseIterable, Identifiable {
    case today = 1, twoDays = 2, threeDays = 3, week = 7

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .twoDays: "Today and tomorrow"
        case .threeDays: "Next 3 days"
        case .week: "Next 7 days"
        }
    }
}

enum AlertLead: Int, CaseIterable, Identifiable {
    case off = -1, atStart = 0, one = 1, two = 2, five = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .atStart: "When the meeting starts"
        case .one: "1 minute before"
        default: "\(rawValue) minutes before"
        }
    }

    var seconds: TimeInterval? {
        self == .off ? nil : TimeInterval(rawValue * 60)
    }
}

enum CalendarApp: String, CaseIterable, Identifiable {
    case apple, google

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: "Calendar"
        case .google: "Google Calendar"
        }
    }
}

enum AlertSound {
    static let all = ["None", "Glass", "Ping", "Pop", "Purr", "Hero", "Submarine", "Tink", "Funk", "Blow", "Bottle", "Frog", "Morse", "Sosumi"]
}

@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    // Menu bar
    @Published var showEventTitle = Preferences.value("showEventTitle", true) { didSet { save("showEventTitle", showEventTitle) } }
    @Published var showEventTime = Preferences.value("showEventTime", true) { didSet { save("showEventTime", showEventTime) } }
    @Published var titleLength = Preferences.value("titleLength", 24) { didSet { save("titleLength", titleLength) } }
    @Published var previewLead = Preferences.option("previewLead", PreviewLead.thirty) { didSet { save("previewLead", previewLead.rawValue) } }

    // Included events
    @Published var dayRange = Preferences.option("dayRange", DayRange.twoDays) { didSet { save("dayRange", dayRange.rawValue) } }
    @Published var includeAllDay = Preferences.value("includeAllDay", true) { didSet { save("includeAllDay", includeAllDay) } }
    @Published var includeWithoutGuests = Preferences.value("includeWithoutGuests", true) { didSet { save("includeWithoutGuests", includeWithoutGuests) } }
    @Published var includeWithoutLocation = Preferences.value("includeWithoutLocation", true) { didSet { save("includeWithoutLocation", includeWithoutLocation) } }
    @Published var hiddenCalendarIDs = Set(Preferences.value("hiddenCalendarIDs", [String]())) { didSet { save("hiddenCalendarIDs", Array(hiddenCalendarIDs)) } }

    // Meeting alerts
    @Published var alertLead = Preferences.option("alertLead", AlertLead.one) { didSet { save("alertLead", alertLead.rawValue) } }
    @Published var alertSound = Preferences.value("alertSound", "Glass") { didSet { save("alertSound", alertSound) } }

    // General
    @Published var globalShortcuts = Preferences.value("globalShortcuts", true) { didSet { save("globalShortcuts", globalShortcuts) } }
    @Published var calendarApp = Preferences.option("calendarApp", CalendarApp.apple) { didSet { save("calendarApp", calendarApp.rawValue) } }

    private init() {}

    private func save(_ key: String, _ value: Any) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private nonisolated static func value<T>(_ key: String, _ fallback: T) -> T {
        UserDefaults.standard.object(forKey: key) as? T ?? fallback
    }

    private nonisolated static func option<T: RawRepresentable>(_ key: String, _ fallback: T) -> T {
        (UserDefaults.standard.object(forKey: key) as? T.RawValue).flatMap(T.init(rawValue:)) ?? fallback
    }
}
