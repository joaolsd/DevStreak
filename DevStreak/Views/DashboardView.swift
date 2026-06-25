import SwiftUI

struct DashboardView: View {
    var vm: StreakViewModel
    @State private var minuteInput: String = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    streakHero
                    statsGrid
                    if vm.consecutivePerfectWeeks > 0 { perfectWeekBadge }
                    logPanel
                    seasonBar
                }
                .padding()
            }
            .navigationTitle("DevStreak")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: shouldShowVerificationSheet) {
                VerificationSheet(vm: vm, pendingMinutes: $minuteInput)
            }
        }
    }

    private var shouldShowVerificationSheet: Binding<Bool> {
        Binding(
            get: {
                switch vm.verificationState {
                case .idle, .checking, .verified: return false
                default: return true
                }
            },
            set: { if !$0 { vm.dismissVerification() } }
        )
    }

    // MARK: – Streak hero

    private var streakHero: some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(vm.currentStreak)")
                    .font(.system(size: 72, weight: .black, design: .monospaced))
                    .foregroundStyle(vm.currentStreak > 0 ? .orange : .secondary)
                Text("day streak")
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if vm.currentStreak > 0 {
                Text("best: \(vm.bestStreak)d")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            todayStatusBadge
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var todayStatusBadge: some View {
        if let s = vm.todaySession {
            if s.freezeUsed {
                Label("Freeze used today", systemImage: "snowflake")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.blue)
            } else if s.isQualified {
                HStack(spacing: 6) {
                    Label("Done · \(s.minutes) min", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    if s.githubVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green.opacity(0.7))
                    } else if s.manualOverride {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow.opacity(0.8))
                    }
                }
                .font(.system(.caption, design: .monospaced))
            } else {
                Text("\(s.minutes) / \(AppConstants.dailyGoalMinutes) min")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Nothing logged yet today")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: – Stats grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(label: "Season score", value: "\(vm.currentSeasonScore)",
                     sub: seasonScoreSub, accent: false)
            StatTile(label: "Freezes left", value: "\(vm.freezesLeft)",
                     sub: vm.bonusFreezesEarned > 0 ? "+\(vm.bonusFreezesEarned) bonus" : "resets Mon",
                     accent: vm.bonusFreezesEarned > 0)
            StatTile(label: "Total days", value: "\(vm.totalDays)",
                     sub: "\(vm.totalMinutes / 60)h coded", accent: false)
            StatTile(label: "Best streak", value: "\(vm.bestStreak)d",
                     sub: nil, accent: false)
        }
    }

    private var seasonScoreSub: String? {
        guard let last = vm.lastSeasonScore else { return nil }
        if vm.currentSeasonScore > last { return "↑ vs \(last) last season" }
        if vm.currentSeasonScore < last { return "↓ vs \(last) last season" }
        return "= \(last) last season"
    }

    // MARK: – Perfect week badge

    private var perfectWeekBadge: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill").foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(vm.consecutivePerfectWeeks) perfect week\(vm.consecutivePerfectWeeks > 1 ? "s" : "")")
                    .font(.subheadline.weight(.semibold).monospaced())
                Text(perfectWeekSub)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(i < vm.consecutivePerfectWeeks ? Color.green : Color(.systemFill))
                        .frame(width: 10, height: 10)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
    }

    private var perfectWeekSub: String {
        switch vm.bonusFreezesEarned {
        case 2: return "Max bonus — +2 freezes this week"
        case 1: return "1 more perfect week → +2 freezes"
        default: return "2 perfect weeks → +1 bonus freeze"
        }
    }

    // MARK: – Log panel

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("LOG SESSION")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if vm.githubEnabled {
                    githubStatusBadge
                }
            }

            HStack(spacing: 10) {
                TextField("minutes", text: $minuteInput)
                    .keyboardType(.numberPad)
                    .focused($inputFocused)
                    .font(.system(.body, design: .monospaced))
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 8))
                    .frame(width: 110)

                Button(action: submitLog) {
                    Group {
                        if case .checking = vm.verificationState {
                            ProgressView().tint(.black)
                        } else {
                            Text("LOG")
                                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(.orange, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.black)
                }
                .disabled(vm.verificationState == .checking.self)

                VStack(spacing: 6) {
                    quickButton("+30") { vm.requestLogMinutes(30) }
                    quickButton("+60") { vm.requestLogMinutes(60) }
                }
            }

            if vm.freezesLeft > 0,
               vm.todaySession?.isQualified != true,
               vm.todaySession?.freezeUsed != true {
                Button(action: { vm.useFreeze() }) {
                    Label("Use streak freeze · \(vm.freezesLeft) left", systemImage: "snowflake")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var githubStatusBadge: some View {
        if vm.todaySession?.githubVerified == true {
            Label("GitHub verified", systemImage: "checkmark.seal.fill")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.green)
        } else {
            Label("GitHub check on log", systemImage: "chevron.left.forwardslash.chevron.right")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func quickButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .frame(width: 48, height: 28)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 6))
        }
        .foregroundStyle(.primary)
    }

    private func submitLog() {
        guard let m = Int(minuteInput), m > 0 else { return }
        inputFocused = false
        vm.requestLogMinutes(m)
        minuteInput = ""
    }

    // MARK: – Season bar

    private var seasonBar: some View {
        let range   = vm.seasonRange
        let total   = Double(AppConstants.seasonWeeks * 7)
        let elapsed = Double(max(0, Calendar.current.dateComponents(
            [.day],
            from: DateHelpers.date(from: range.start) ?? Date(),
            to: Date()
        ).day ?? 0) + 1)
        let progress = min(elapsed / total, 1.0)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SEASON PROGRESS")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let last = vm.lastSeasonScore {
                    Text("target: \(last + 1) pts")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            ProgressView(value: progress).tint(.orange).scaleEffect(x: 1, y: 1.6)
            Text("30–59m=1pt · 60–89m=2pt · 90–119m=3pt · 120+m=4pt")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: – Verification sheet

struct VerificationSheet: View {
    var vm: StreakViewModel
    @Binding var pendingMinutes: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                icon
                title
                detail
                actions
                Spacer()
            }
            .padding(28)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        vm.dismissVerification()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var icon: some View {
        switch vm.verificationState {
        case .onlyTrivial:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48)).foregroundStyle(.yellow)
        case .noCommits:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48)).foregroundStyle(.orange)
        case .networkError:
            Image(systemName: "wifi.slash")
                .font(.system(size: 48)).foregroundStyle(.red)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var title: some View {
        switch vm.verificationState {
        case .onlyTrivial:
            Text("Only trivial commits found")
                .font(.system(.title3, design: .monospaced, weight: .bold))
        case .noCommits:
            Text("No commits today")
                .font(.system(.title3, design: .monospaced, weight: .bold))
        case .networkError:
            Text("GitHub unreachable")
                .font(.system(.title3, design: .monospaced, weight: .bold))
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch vm.verificationState {
        case .onlyTrivial(let commits):
            VStack(alignment: .leading, spacing: 8) {
                Text("Commits found but none cleared the threshold (±\(AppConstants.githubMinNetLines) lines or \(AppConstants.githubMinFiles)+ files):")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                ForEach(commits.prefix(3), id: \.sha) { c in
                    HStack(alignment: .top, spacing: 8) {
                        Text("·")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.message.components(separatedBy: "\n").first ?? c.message)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                            Text("+\(c.additions) −\(c.deletions) · \(c.filesChanged) file\(c.filesChanged == 1 ? "" : "s")")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        case .noCommits:
            Text("No push events found for @\(vm.githubUsername) today. Go write some code, then log your session.")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        case .networkError(let msg):
            Text("Could not reach GitHub: \(msg)\nYou can log anyway — it'll show as unverified.")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 12) {
            // Log anyway (always available, marks as manual override)
            Button(action: {
                vm.forceLogPendingMinutes()
                dismiss()
            }) {
                Text("Log anyway (unverified)")
                    .font(.system(.subheadline, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.secondary)
            }

            // Dismiss — go commit something
            if case .noCommits = vm.verificationState {
                Button(action: {
                    vm.dismissVerification()
                    dismiss()
                }) {
                    Text("Go write some code first")
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(.orange, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.black)
                }
            }
        }
    }
}

// MARK: – Stat tile (shared)

struct StatTile: View {
    let label: String
    let value: String
    let sub: String?
    let accent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundStyle(accent ? .orange : .primary)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            if let sub {
                Text(sub)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
    }
}

// Needed for the disabled check
extension StreakViewModel.VerificationState: Equatable {
    static func == (lhs: StreakViewModel.VerificationState, rhs: StreakViewModel.VerificationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking),
             (.noCommits, .noCommits), (.notConfigured, .notConfigured): return true
        default: return false
        }
    }
}
