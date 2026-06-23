import Foundation

/// All game-logic computations. Pure functions, no SwiftData dependency.
enum StreakLogic {

    // MARK: – Streak

    /// Consecutive qualified days ending on or before today.
    /// If today has no entry yet, we look back from yesterday so opening
    /// the app in the morning doesn't zero the streak.
    static func currentStreak(sessions: [String: CodingSession]) -> Int {
        let today = DateHelpers.todayKey()
        var checkKey = today
        if sessions[checkKey]?.isQualified != true {
            checkKey = DateHelpers.adding(days: -1, to: today) ?? today
        }
        var streak = 0
        var key: String? = checkKey
        while let k = key, let s = sessions[k], s.isQualified {
            streak += 1
            key = DateHelpers.adding(days: -1, to: k)
        }
        return streak
    }

    // MARK: – Season

    /// Season always starts on the Monday of the current ISO week and spans
    /// `AppConstants.seasonWeeks` weeks forward.
    static func currentSeasonRange() -> (start: String, end: String) {
        let start = DateHelpers.weekStartKey()
        let endDate = Calendar.current.date(
            byAdding: .weekOfYear,
            value: AppConstants.seasonWeeks,
            to: DateHelpers.weekStart()
        ).flatMap { DateHelpers.adding(days: -1, to: DateHelpers.key(for: $0)) }
        return (start, endDate ?? start)
    }

    static func score(for session: CodingSession) -> Int {
        guard session.isQualified, !session.freezeUsed else { return 0 }
        switch session.minutes {
        case 120...: return 4
        case 90...:  return 3
        case 60...:  return 2
        default:     return 1
        }
    }

    static func seasonScore(sessions: [String: CodingSession], start: String, end: String) -> Int {
        DateHelpers.dayKeys(from: start, through: end)
            .compactMap { sessions[$0] }
            .reduce(0) { $0 + score(for: $1) }
    }

    // MARK: – Perfect weeks & bonus freezes

    /// A "perfect week" = all 5 weekdays (Mon–Fri) qualified.
    static func isPerfectWeek(sessions: [String: CodingSession], weekStart: Date) -> Bool {
        DateHelpers.weekdayKeys(weekStart: weekStart).allSatisfy {
            sessions[$0]?.isQualified == true
        }
    }

    /// Count of consecutive perfect weekday-weeks ending with last week.
    static func consecutivePerfectWeeks(sessions: [String: CodingSession]) -> Int {
        var count = 0
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        for w in 1...8 {
            guard let ws = cal.date(byAdding: .weekOfYear, value: -w, to: Date()) else { break }
            let monday = DateHelpers.weekStart(for: ws)
            if isPerfectWeek(sessions: sessions, weekStart: monday) { count += 1 }
            else { break }
        }
        return count
    }

    static func bonusFreezesEarned(sessions: [String: CodingSession]) -> Int {
        let perf = consecutivePerfectWeeks(sessions: sessions)
        if perf >= 3 { return AppConstants.bonusFreezesAt3Weeks }
        if perf >= 2 { return AppConstants.bonusFreezesAt2Weeks }
        return 0
    }

    // MARK: – All-time best streak

    static func bestStreak(sessions: [String: CodingSession]) -> Int {
        var best = 0, cur = 0
        for key in DateHelpers.last365DayKeys() {
            if sessions[key]?.isQualified == true { cur += 1 } else { cur = 0 }
            if cur > best { best = cur }
        }
        return best
    }
}
