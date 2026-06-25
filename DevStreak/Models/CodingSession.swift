import Foundation
import SwiftData

/// A single day's coding record.
/// One row per calendar day — multiple log calls accumulate into `minutes`.
@Model
final class CodingSession {
    /// Canonical date key: "yyyy-MM-dd" in the user's local calendar.
    var dateKey: String
    /// Accumulated minutes logged for this day.
    var minutes: Int
    /// Whether a streak-freeze was used instead of coding.
    var freezeUsed: Bool
    /// GitHub verification state for this day.
    var githubVerified: Bool
    /// Manual override — user logged without GitHub verification.
    /// Shown in a distinct colour on the heat map.
    var manualOverride: Bool

    /// True when the day counts toward the streak (≥ goal or freeze).
    var isQualified: Bool { minutes >= AppConstants.dailyGoalMinutes || freezeUsed }

    init(
        dateKey: String,
        minutes: Int = 0,
        freezeUsed: Bool = false,
        githubVerified: Bool = false,
        manualOverride: Bool = false
    ) {
        self.dateKey        = dateKey
        self.minutes        = minutes
        self.freezeUsed     = freezeUsed
        self.githubVerified = githubVerified
        self.manualOverride = manualOverride
    }
}
