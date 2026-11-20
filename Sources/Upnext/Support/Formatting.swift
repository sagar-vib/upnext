import Foundation

enum Fmt {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return formatter
    }()

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    /// "10:00 AM - 10:30 AM" or "All day".
    static func range(_ event: CalendarEvent) -> String {
        event.isAllDay ? "All day" : "\(time(event.start)) - \(time(event.end))"
    }

    /// "Today", "Tomorrow" or the weekday name.
    static func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        return weekdayFormatter.string(from: day)
    }

    /// "Fri, Nov 20".
    static func shortDate(_ day: Date) -> String {
        shortDateFormatter.string(from: day)
    }

    /// Menu bar style: "5m", "1h 20m".
    static func compactDuration(_ interval: TimeInterval) -> String {
        let minutes = wholeMinutes(interval)
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }

    /// Panel style: "5 min", "1 hr 20 min".
    static func duration(_ interval: TimeInterval) -> String {
        let minutes = wholeMinutes(interval)
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? "\(hours) hr" : "\(hours) hr \(rest) min"
    }

    /// Top card label: "In 12 min", "Now · 18 min left", "Tomorrow, 9:00 AM".
    static func relative(_ event: CalendarEvent, now: Date) -> String {
        if event.isOngoing(at: now) {
            return "Now · \(duration(event.end.timeIntervalSince(now))) left"
        }
        let until = event.start.timeIntervalSince(now)
        if until < 60 { return "Starting now" }
        if Calendar.current.isDate(event.start, inSameDayAs: now) || until < 6 * 3600 {
            return "In \(duration(until))"
        }
        return "\(dayTitle(event.start)), \(time(event.start))"
    }

    /// Alert label: "Starts in 1 min", "Starting now", "Started 2 min ago".
    static func alertStatus(_ event: CalendarEvent, now: Date) -> String {
        let until = event.start.timeIntervalSince(now)
        if until >= 60 { return "Starts in \(duration(until))" }
        if until > -60 { return "Starting now" }
        return "Started \(duration(-until)) ago"
    }

    /// Menu bar title: "Weekly sync · in 5m", "Design review · 20m left".
    static func menuBarTitle(_ event: CalendarEvent, now: Date, showTitle: Bool, showTime: Bool, maxLength: Int) -> String {
        var parts: [String] = []
        if showTitle {
            parts.append(truncate(event.title, to: maxLength))
        }
        if showTime {
            let until = event.start.timeIntervalSince(now)
            if event.isOngoing(at: now) {
                parts.append("\(compactDuration(event.end.timeIntervalSince(now))) left")
            } else if until < 60 {
                parts.append("now")
            } else {
                parts.append("in \(compactDuration(until))")
            }
        }
        return parts.joined(separator: " · ")
    }

    static func guestSummary(_ guests: [Attendee]) -> String {
        let yes = guests.filter { $0.status == .accepted }.count
        let no = guests.filter { $0.status == .declined }.count
        let maybe = guests.filter { $0.status == .tentative }.count
        let waiting = guests.count - yes - no - maybe
        var parts = ["\(guests.count) guest\(guests.count == 1 ? "" : "s")"]
        if yes > 0 { parts.append("\(yes) yes") }
        if no > 0 { parts.append("\(no) no") }
        if maybe > 0 { parts.append("\(maybe) maybe") }
        if waiting > 0 { parts.append("\(waiting) awaiting") }
        return parts.joined(separator: " · ")
    }

    static func truncate(_ text: String, to length: Int) -> String {
        guard text.count > length, length > 1 else { return text }
        return text.prefix(length - 1).trimmingCharacters(in: .whitespaces) + "…"
    }

    private static func wholeMinutes(_ interval: TimeInterval) -> Int {
        max(1, Int((interval / 60).rounded(.up)))
    }
}
