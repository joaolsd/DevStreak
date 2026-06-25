import Foundation
import SwiftData
import Combine

@MainActor
@Observable
final class StreakViewModel {

    // MARK: – Injected
    private let modelContext: ModelContext
    private let defaults: UserDefaults

    // MARK: – State
    private(set) var sessionsMap: [String: CodingSession] = [:]
    private(set) var freezesLeft: Int = AppConstants.baseFreezesPerWeek
    private(set) var lastSeasonScore: Int? = nil
    private(set) var notification: String? = nil

    /// GitHub config (loaded from defaults / keychain)
    private(set) var githubUsername: String = ""
    var githubEnabled: Bool { !githubUsername.isEmpty }

    /// Verification state for the current log attempt
    enum VerificationState {
        case idle
        case checking
        case verified([GitHubService.CommitSummary])
        case onlyTrivial([GitHubService.CommitSummary])
        case noCommits
        case networkError(String)
        case notConfigured
    }
    private(set) var verificationState: VerificationState = .idle
    /// Minutes pending commit while we wait for GitHub check
    private var pendingMinutes: Int = 0

    // MARK: – Init
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
        loadSessions()
        loadDefaults()
        handleWeeklyFreezeRefill()
    }

    // MARK: – Derived

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

    // MARK: – Log with optional GitHub check

    /// Entry point from the UI. If GitHub is configured and today isn't
    /// already verified, runs the check first and surfaces the result.
    func requestLogMinutes(_ minutes: Int) {
        pendingMinutes = minutes

        // If GitHub not configured, or day already verified, skip check
        if !githubEnabled || todaySession?.githubVerified == true {
            commitLog(minutes: minutes, verified: todaySession?.githubVerified ?? false, manual: !githubEnabled)
            return
        }

        verificationState = .checking
        Task {
            let token = KeychainHelper.load(
                service: AppConstants.keychainTokenService,
                account: AppConstants.keychainTokenAccount
            )
            let result = await GitHubService.shared.verifyToday(
                username: githubUsername, token: token
            )
            await MainActor.run { handleVerificationResult(result) }
        }
    }

    /// Called when the user taps "Log anyway" after a non-verified result.
    func forceLogPendingMinutes() {
        commitLog(minutes: pendingMinutes, verified: false, manual: true)
        verificationState = .idle
    }

    func dismissVerification() {
        verificationState = .idle
        pendingMinutes = 0
    }

    // MARK: – Freeze

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

    // MARK: – GitHub config

    func saveGitHubUsername(_ username: String) {
        githubUsername = username.trimmingCharacters(in: .whitespaces)
        defaults.set(githubUsername, forKey: AppConstants.githubUsernameKey)
    }

    func saveGitHubToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            KeychainHelper.delete(
                service: AppConstants.keychainTokenService,
                account: AppConstants.keychainTokenAccount
            )
        } else {
            KeychainHelper.save(
                trimmed,
                service: AppConstants.keychainTokenService,
                account: AppConstants.keychainTokenAccount
            )
        }
    }

    func clearGitHubConfig() {
        githubUsername = ""
        defaults.removeObject(forKey: AppConstants.githubUsernameKey)
        KeychainHelper.delete(
            service: AppConstants.keychainTokenService,
            account: AppConstants.keychainTokenAccount
        )
    }

    // MARK: – Private

    private func handleVerificationResult(_ result: GitHubService.VerificationResult) {
        switch result {
        case .verified(let commits):
            verificationState = .verified(commits)
            commitLog(minutes: pendingMinutes, verified: true, manual: false)

        case .onlyTrivial(let commits):
            verificationState = .onlyTrivial(commits)
            // Don't auto-commit — surface the result and let the user decide

        case .noCommitsToday:
            verificationState = .noCommits

        case .networkError(let msg):
            verificationState = .networkError(msg)

        case .notConfigured:
            verificationState = .notConfigured
            commitLog(minutes: pendingMinutes, verified: false, manual: true)
        }
    }

    private func commitLog(minutes: Int, verified: Bool, manual: Bool) {
        let key = todayKey
        if let existing = sessionsMap[key] {
            existing.minutes += minutes
            if verified { existing.githubVerified = true }
            if manual   { existing.manualOverride = true }
        } else {
            let s = CodingSession(
                dateKey: key, minutes: minutes,
                githubVerified: verified, manualOverride: manual
            )
            modelContext.insert(s)
            sessionsMap[key] = s
        }
        try? modelContext.save()

        let total      = sessionsMap[key]?.minutes ?? minutes
        let goalMet    = total >= AppConstants.dailyGoalMinutes
        let wasGoalMet = (total - minutes) >= AppConstants.dailyGoalMinutes

        if goalMet && !wasGoalMet {
            let tag = verified ? " ✓ GitHub" : (manual ? " · unverified" : "")
            showNotification("✓ Goal reached — streak protected\(tag)")
        } else if !goalMet {
            showNotification("+\(minutes) min · \(AppConstants.dailyGoalMinutes - total) min to go")
        } else {
            showNotification("+\(minutes) min logged")
        }

        writeSharedDefaults()
        if verificationState.isTerminal { verificationState = .idle }
    }

    private func loadSessions() {
        let descriptor = FetchDescriptor<CodingSession>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        sessionsMap = Dictionary(uniqueKeysWithValues: all.map { ($0.dateKey, $0) })
    }

    private func loadDefaults() {
        freezesLeft    = defaults.integer(forKey: AppConstants.freezesLeftKey)
        let stored     = defaults.integer(forKey: AppConstants.lastSeasonScoreKey)
        lastSeasonScore = stored > 0 ? stored : nil
        githubUsername  = defaults.string(forKey: AppConstants.githubUsernameKey) ?? ""

        if defaults.object(forKey: AppConstants.freezesLeftKey) == nil {
            freezesLeft = AppConstants.baseFreezesPerWeek
            defaults.set(freezesLeft, forKey: AppConstants.freezesLeftKey)
        }
    }

    private func handleWeeklyFreezeRefill() {
        let currentWeekStart = DateHelpers.weekStartKey()
        let storedWeekStart  = defaults.string(forKey: AppConstants.freezeWeekKey) ?? ""
        guard currentWeekStart != storedWeekStart else { return }

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
        guard todayKey > r.end else { return }
        let score = StreakLogic.seasonScore(sessions: sessionsMap, start: r.start, end: r.end)
        lastSeasonScore = score
        defaults.set(score, forKey: AppConstants.lastSeasonScoreKey)
    }

    private func writeSharedDefaults() {
        defaults.set(currentStreak,      forKey: "widget_streak")
        defaults.set(currentSeasonScore, forKey: "widget_seasonScore")
        defaults.set(todaySession?.isQualified == true,    forKey: "widget_todayDone")
        defaults.set(todaySession?.freezeUsed == true,     forKey: "widget_todayFreeze")
        defaults.set(todaySession?.githubVerified == true, forKey: "widget_todayVerified")
    }

    func showNotification(_ message: String) {
        notification = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            if notification == message { notification = nil }
        }
    }
}

extension StreakViewModel.VerificationState {
    /// Whether the state represents a completed flow that should auto-clear.
    var isTerminal: Bool {
        if case .verified = self { return true }
        return false
    }
}
