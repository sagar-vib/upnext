import Foundation

/// A day that starts at `startHour` instead of midnight, so meetings in the small hours
/// (12:30 AM when working with US Eastern time, say) belong to the day they're part of.
struct WorkDay {
    let startHour: Int

    /// Start of the work day containing `date`: with a 4 AM start, Tuesday 1 AM is in the
    /// day that began Monday 4 AM.
    func start(containing date: Date) -> Date {
        let calendar = Calendar.current
        let shifted = calendar.date(byAdding: .hour, value: -startHour, to: date) ?? date
        let day = calendar.startOfDay(for: shifted)
        return calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: day) ?? day
    }

    /// 0 for the same work day as `now`, 1 for the next one, and so on.
    func offset(of date: Date, from now: Date) -> Int {
        Calendar.current.dateComponents([.day], from: start(containing: now), to: start(containing: date)).day ?? 0
    }
}
