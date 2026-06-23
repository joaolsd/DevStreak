import Foundation

enum DateHelpers {

    static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    static func todayKey() -> String {
        keyFormatter.string(from: Date())
    }

    static func key(for date: Date) -> String {
        keyFormatter.string(from: date)
    }

    static func date(from key: String) -> Date? {
        keyFormatter.date(from: key)
    }

    /// Monday of the ISO week containing `date`.
    static func weekStart(for date: Date = Date()) -> Date {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? date
    }

    static func weekStartKey(for date: Date = Date()) -> String {
        key(for: weekStart(for: date))
    }

    /// Returns date keys for the 365 days ending today, oldest first.
    static func last365DayKeys() -> [String] {
        let today = Date()
        var cal = Calendar.current
        cal.timeZone = .current
        return (0..<365).reversed().compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: today).map { key(for: $0) }
        }
    }

    /// True when `dateKey` falls on a Saturday or Sunday.
    static func isWeekend(_ dateKey: String) -> Bool {
        guard let d = date(from: dateKey) else { return false }
        let weekday = Calendar.current.component(.weekday, from: d)
        return weekday == 1 || weekday == 7
    }

    /// The Mon–Fri date keys for the week that started on `weekStartDate`.
    static func weekdayKeys(weekStart weekStartDate: Date) -> [String] {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return (0..<5).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: weekStartDate).map { key(for: $0) }
        }
    }

    /// All date keys from `start` through `end` inclusive.
    static func dayKeys(from start: String, through end: String) -> [String] {
        guard let s = date(from: start), let e = date(from: end), s <= e else { return [] }
        var result: [String] = []
        var cur = s
        let cal = Calendar.current
        while cur <= e {
            result.append(key(for: cur))
            guard let next = cal.date(byAdding: .day, value: 1, to: cur) else { break }
            cur = next
        }
        return result
    }

    static func adding(days n: Int, to dateKey: String) -> String? {
        guard let d = date(from: dateKey),
              let result = Calendar.current.date(byAdding: .day, value: n, to: d)
        else { return nil }
        return key(for: result)
    }
}
