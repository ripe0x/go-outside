import Foundation

/// A deliberately small persistence boundary: one total, labeled with its local day.
final class TodayStore {
    private enum Key {
        static let date = "go.outside.today.date"
        static let seconds = "go.outside.today.seconds"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(now: Date, calendar: Calendar) -> Double {
        let maximum = dayDuration(for: now, calendar: calendar)
        let rawSeconds = defaults.object(forKey: Key.seconds)
        guard defaults.string(forKey: Key.date) == dayLabel(for: now, calendar: calendar),
              !(rawSeconds is Bool),
              let seconds = rawSeconds as? Double,
              seconds.isFinite,
              seconds >= 0,
              seconds <= maximum else {
            return 0
        }
        return seconds
    }

    func save(seconds: Double, now: Date, calendar: Calendar) {
        let sanitized = seconds.isFinite ? min(dayDuration(for: now, calendar: calendar), max(0, seconds)) : 0
        defaults.set(dayLabel(for: now, calendar: calendar), forKey: Key.date)
        defaults.set(sanitized, forKey: Key.seconds)
    }

    private func dayLabel(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return "\(components.era ?? 0)-\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func dayDuration(for date: Date, calendar: Calendar) -> Double {
        calendar.dateInterval(of: .day, for: date)?.duration ?? 0
    }
}
