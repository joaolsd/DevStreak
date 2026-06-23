import SwiftUI

struct SettingsView: View {
    var vm: StreakViewModel

    @State private var reminderEnabled = false
    @State private var reminderTime    = Date()
    @State private var authStatus      = ""
    @State private var isLoading       = true

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
        }
    }

    // MARK: – Reminder row

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
