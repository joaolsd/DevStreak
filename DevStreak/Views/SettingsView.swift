import SwiftUI

struct SettingsView: View {
    var vm: StreakViewModel

    @State private var reminderEnabled = false
    @State private var reminderTime    = Date()
    @State private var authStatus      = ""
    @State private var isLoading       = true

    // GitHub config
    @State private var githubUsername  = ""
    @State private var githubToken     = ""
    @State private var showToken       = false
    @State private var githubTestResult: String? = nil
    @State private var isTesting       = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    reminderRow
                } header: {
                    Text("Daily Reminder")
                } footer: {
                    Text(authStatus)
                        .font(.system(.caption2, design: .monospaced))
                }

                Section {
                    githubSection
                } header: {
                    Text("GitHub Verification")
                } footer: {
                    Text("Logs without a qualifying commit are marked unverified and shown in yellow on the heat map. A qualifying commit has ±\(AppConstants.githubMinNetLines)+ lines or \(AppConstants.githubMinFiles)+ files changed.")
                        .font(.system(.caption2, design: .monospaced))
                }

                Section("Freeze Rules") {
                    ruleRow("Base freezes per week", value: "\(AppConstants.baseFreezesPerWeek)")
                    ruleRow("2 perfect Mon–Fri weeks", value: "+1 bonus freeze")
                    ruleRow("3 perfect Mon–Fri weeks", value: "+2 bonus freezes")
                    ruleRow("Weekends", value: "never count against streak")
                }

                Section("Scoring") {
                    ruleRow("30–59 min", value: "1 pt")
                    ruleRow("60–89 min", value: "2 pts")
                    ruleRow("90–119 min", value: "3 pts")
                    ruleRow("120+ min",  value: "4 pts")
                }

                Section("About") {
                    ruleRow("Daily goal", value: "\(AppConstants.dailyGoalMinutes) minutes")
                    ruleRow("Season length", value: "\(AppConstants.seasonWeeks) weeks")
                }
            }
            .navigationTitle("Settings")
            .task { await loadNotificationState() }
            .onAppear { loadGitHubConfig() }
        }
    }

    // MARK: – GitHub section

    @ViewBuilder
    private var githubSection: some View {
        HStack {
            Text("Username")
                .font(.system(.body, design: .monospaced))
            Spacer()
            TextField("your-handle", text: $githubUsername)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { vm.saveGitHubUsername(githubUsername) }
        }

        HStack {
            Text("Token")
                .font(.system(.body, design: .monospaced))
            Spacer()
            Group {
                if showToken {
                    TextField("ghp_…", text: $githubToken)
                } else {
                    SecureField("ghp_…", text: $githubToken)
                }
            }
            .font(.system(.body, design: .monospaced))
            .multilineTextAlignment(.trailing)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit { vm.saveGitHubToken(githubToken) }

            Button(action: { showToken.toggle() }) {
                Image(systemName: showToken ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
        }

        HStack(spacing: 12) {
            Button("Save") {
                vm.saveGitHubUsername(githubUsername)
                vm.saveGitHubToken(githubToken)
            }
            .font(.system(.subheadline, design: .monospaced))
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Button("Test") {
                Task { await testGitHub() }
            }
            .font(.system(.subheadline, design: .monospaced))
            .disabled(githubUsername.isEmpty || isTesting)

            if isTesting { ProgressView() }
        }

        if let result = githubTestResult {
            Text(result)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(result.hasPrefix("✓") ? .green : .orange)
        }

        if vm.githubEnabled {
            Button("Clear GitHub config", role: .destructive) {
                vm.clearGitHubConfig()
                githubUsername = ""
                githubToken    = ""
                githubTestResult = nil
            }
            .font(.system(.subheadline, design: .monospaced))
        }
    }

    private func loadGitHubConfig() {
        githubUsername = vm.githubUsername
        // Don't pre-fill token — user must re-enter if they want to change it
    }

    private func testGitHub() async {
        isTesting = true
        githubTestResult = nil
        let token = githubToken.isEmpty
            ? KeychainHelper.load(service: AppConstants.keychainTokenService, account: AppConstants.keychainTokenAccount)
            : githubToken
        let result = await GitHubService.shared.verifyToday(username: githubUsername, token: token)
        switch result {
        case .verified(let commits):
            githubTestResult = "✓ Found \(commits.count) qualifying commit\(commits.count == 1 ? "" : "s") today"
        case .onlyTrivial(let commits):
            githubTestResult = "⚠ \(commits.count) commit\(commits.count == 1 ? "" : "s") found but all below threshold"
        case .noCommitsToday:
            githubTestResult = "No commits pushed today (API reachable)"
        case .networkError(let msg):
            githubTestResult = "Network error: \(msg)"
        case .notConfigured:
            githubTestResult = "Username not set"
        }
        isTesting = false
    }

    // MARK: – Reminder section

    @ViewBuilder
    private var reminderRow: some View {
        if isLoading {
            ProgressView()
        } else {
            Toggle("Remind me daily", isOn: $reminderEnabled)
                .onChange(of: reminderEnabled) { _, enabled in
                    Task { await toggleReminder(enabled) }
                }
            if reminderEnabled {
                DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .onChange(of: reminderTime) { _, newTime in
                        Task { await updateReminderTime(newTime) }
                    }
            }
        }
    }

    private func ruleRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.body, design: .monospaced))
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: – Notification state

    private func loadNotificationState() async {
        isLoading = true
        let status = await NotificationManager.shared.authorizationStatus()
        switch status {
        case .authorized, .provisional:
            authStatus = "Notifications authorised"
            if let t = await NotificationManager.shared.scheduledReminderTime() {
                reminderEnabled = true
                var comps        = Calendar.current.dateComponents([.hour, .minute], from: Date())
                comps.hour       = t.hour
                comps.minute     = t.minute
                reminderTime     = Calendar.current.date(from: comps) ?? Date()
            }
        case .denied:
            authStatus = "Notifications blocked — enable in Settings → DevStreak"
            reminderEnabled = false
        default:
            authStatus = "Tap toggle to request notification permission"
        }
        isLoading = false
    }

    private func toggleReminder(_ enabled: Bool) async {
        if enabled {
            await NotificationManager.shared.scheduleDailyReminder(
                hour:   Calendar.current.component(.hour,   from: reminderTime),
                minute: Calendar.current.component(.minute, from: reminderTime)
            )
            await loadNotificationState()
        } else {
            NotificationManager.shared.cancelDailyReminder()
            authStatus = "Reminder cancelled"
        }
    }

    private func updateReminderTime(_ time: Date) async {
        let h = Calendar.current.component(.hour,   from: time)
        let m = Calendar.current.component(.minute, from: time)
        await NotificationManager.shared.scheduleDailyReminder(hour: h, minute: m)
    }
}
