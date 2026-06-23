import Foundation
import SwiftData
import Combine

@MainActor
@Observable
final class StreakViewModel {

    // MARK: – Injected
    private let modelContext: ModelContext
    private let defaults: UserDefaults

    // MARK: – Published state
    private(set) var sessionsMap: [String: CodingSession] = [:]
    private(set) var freezesLeft: Int = AppConstants.baseFreezesPerWeek
    private(set) var lastSeasonScore: Int? = nil
    private(set) var notification: String? = nil

    // MARK: – Init
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
        loadSessions()
        loadDefaults()
        handleWeeklyFreezeRefill()
    }

    // MARK: – Derived (computed fresh each access)

    var todayKey: String { DateHelpers.todayKey() }
    var todaySession: CodingSession? { sessionsMap[todayKey] }

    var currentStreak: Int { StreakLogic.currentStreak(sessions: sessionsMap) }
    var bestStreak: Int    { StreakLogic.bestStreak(sessions: sessionsMap) }

    var seasonRange: (start: String, end: String) { StreakLogic.currentSeasonRange() }
    var currentSeasonScore: Int {
        let r = seasonRange
        return StreakLogic.seasonScore(sessions: sessionsMap, start: r.start, end: r.end)
    }

    var consecutivePerfectWeeks: Int { StreakLogic.consecutivePerfectWeeks(sessions: sessionsMap) }
    var bonusFreezesEarned: Int      { StreakLogic.bonusFreezesEarned(sessions: sessionsMap) }

    var totalDays: Int    { sessionsMap.values.filter(\.isQualified).count }
    var totalMinutes: Int { sessionsMap.values.reduce(0) { $0 + $1.minutes } }

    // MARK: – Actions

    func logMinutes(_ minutes: Int) {
        let key = todayKey
        if let existing = sessionsMap[key] {
            existing.minutes += minutes
        } else {
            let s = CodingSession(dateKey: key, minutes: minutes)
            modelContext.insert(s)
            sessionsMap[key] = s
        }
        try? modelContext.save()

        let total = sessionsMap[key]?.minutes ?? minutes
        let goalMet = total >= AppConstants.dailyGoalMinutes
        let wasGoalMet = (total - minutes) >= AppConstants.dailyGoalMinutes

        if goalMet && !wasGoalMet {
            showNotification("✓ Goal reached — streak protected")
        } else if !goalMet {
            showNotification("+\(minutes) min · \(AppConstants.dailyGoalMinutes - total) min to go")
        } else {
            showNotification("+\(minutes) min logged")
        }

        writeSharedDefaults()
    }

    func useFreeze() {
        guard freezesLeft > 0 else { return }
        let key = todayKey
        guard sessionsMap[key]?.isQualified != true,
              sessionsMap[key]?.freezeUsed != true else { return }

        if let existing = sessionsMap[key] {
            existing.freezeUsed = true
        } else {
            let s = CodingSession(dateKey: key, freezeUsed: true)
            modelContext.insert(s)
            sessionsMap[key] = s
        }
        try? modelContext.save()

        freezesLeft -= 1
        defaults.set(freezesLeft, forKey: AppConstants.freezesLeftKey)
        showNotification("❄ Freeze used · \(freezesLeft) left this week")
        writeSharedDefaults()
    }

    // MARK: – Private

    private func loadSessions() {
        let descriptor = FetchDescriptor<CodingSession>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        sessionsMap = Dictionary(uniqueKeysWithValues: all.map { ($0.dateKey, $0) })
    }

    private func loadDefaults() {
        freezesLeft   = defaults.integer(forKey: AppConstants.freezesLeftKey)
        let stored    = defaults.integer(forKey: AppConstants.lastSeasonScoreKey)
        lastSeasonScore = stored > 0 ? stored : nil

        // First launch — set sensible defaults
        if defaults.object(forKey: AppConstants.freezesLeftKey) == nil {
            freezesLeft = AppConstants.baseFreezesPerWeek
            defaults.set(freezesLeft, forKey: AppConstants.freezesLeftKey)
        }
    }

    private func handleWeeklyFreezeRefill() {
        let currentWeekStart = DateHelpers.weekStartKey()
        let storedWeekStart  = defaults.string(forKey: AppConstants.freezeWeekKey) ?? ""

        guard currentWeekStart != storedWeekStart else { return }

        // New week — archive season score if needed, refill freezes
        archiveSeasonIfNeeded()

        let bonus = StreakLogic.bonusFreezesEarned(sessions: sessionsMap)
        freezesLeft = AppConstants.baseFreezesPerWeek + bonus
        defaults.set(freezesLeft, forKey: AppConstants.freezesLeftKey)
        defaults.set(currentWeekStart, forKey: AppConstants.freezeWeekKey)

        if bonus > 0 {
            showNotification("🎁 +\(bonus) bonus freeze\(bonus > 1 ? "s" : "") for \(consecutivePerfectWeeks) perfect weeks!")
        }
    }

    private func archiveSeasonIfNeeded() {
        let r = seasonRange
        let today = todayKey
        guard today > r.end else { return }
        let score = StreakLogic.seasonScore(sessions: sessionsMap, start: r.start, end: r.end)
        lastSeasonScore = score
        defaults.set(score, forKey: AppConstants.lastSeasonScoreKey)
    }

    /// Write widget-readable snapshot to shared UserDefaults.
    private func writeSharedDefaults() {
        defaults.set(currentStreak,      forKey: "widget_streak")
        defaults.set(currentSeasonScore, forKey: "widget_seasonScore")
        defaults.set(todaySession?.isQualified == true, forKey: "widget_todayDone")
        defaults.set(todaySession?.freezeUsed == true,  forKey: "widget_todayFreeze")
    }

    func showNotification(_ message: String) {
        notification = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            if notification == message { notification = nil }
        }
    }
}
