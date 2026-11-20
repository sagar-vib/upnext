import AppKit

/// Actions available from the panel, the top card and meeting alerts.
@MainActor
enum EventActions {
    static func join(_ event: CalendarEvent) {
        guard let link = event.meeting else { return }
        NSWorkspace.shared.open(link.launchURL(accountEmail: event.accountEmail))
    }

    static func open(_ event: CalendarEvent) {
        switch Preferences.shared.calendarApp {
        case .apple:
            let id = event.eventIdentifier.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? event.eventIdentifier
            if let url = URL(string: "ical://ekevent/\(id)?method=show&options=more") {
                NSWorkspace.shared.open(url)
            }
        case .google:
            openGoogleCalendar(day: event.start, account: event.accountEmail)
        }
    }

    static func openCalendarApp() {
        switch Preferences.shared.calendarApp {
        case .apple:
            if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
                NSWorkspace.shared.open(app)
            }
        case .google:
            openGoogleCalendar(day: Date(), account: nil)
        }
    }

    static func openCalendarPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func openGoogleCalendar(day: Date, account: String?) {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: day)
        var components = URLComponents(string: "https://calendar.google.com/calendar/r/day")
        components?.path += "/\(parts.year ?? 0)/\(parts.month ?? 1)/\(parts.day ?? 1)"
        if let account {
            components?.queryItems = [URLQueryItem(name: "authuser", value: account)]
        }
        if let url = components?.url {
            NSWorkspace.shared.open(url)
        }
    }
}
