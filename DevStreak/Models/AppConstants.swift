import Foundation

enum AppConstants {
    static let dailyGoalMinutes = 30

    /// Freezes granted at the start of every week.
    static let baseFreezesPerWeek = 2

    /// Extra freezes for 2 consecutive perfect weekday-weeks.
    static let bonusFreezesAt2Weeks = 1

    /// Extra freezes for 3 consecutive perfect weekday-weeks.
    static let bonusFreezesAt3Weeks = 2

    static let seasonWeeks = 4

    /// UserDefaults / AppGroup suite name — must match widget target.
    static let appGroupID = "group.org.bondis.devstreak"

    // UserDefaults keys
    static let freezesLeftKey      = "freezesLeft"
    static let freezeWeekKey       = "freezeWeekStart"  // stores ISO week-start
    static let lastSeasonScoreKey  = "lastSeasonScore"
    static let reminderHourKey     = "reminderHour"
    static let reminderMinuteKey   = "reminderMinute"
}
