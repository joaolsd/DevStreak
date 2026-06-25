import SwiftUI

struct HeatMapView: View {
    var vm: StreakViewModel

    private let cellSize: CGFloat = 12
    private let gap: CGFloat = 3
    private let days = DateHelpers.last365DayKeys()

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 4) {
                    monthRow
                    HStack(alignment: .top, spacing: gap) {
                        weekdayLabels
                        weeksGrid
                    }
                    legend
                }
                .padding()
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: – Sub-views

    private var monthRow: some View {
        HStack(spacing: 0) {
            // Offset for weekday labels column
            Color.clear.frame(width: 22)
            ForEach(monthPositions, id: \.label) { pos in
                Color.clear
                    .frame(width: (cellSize + gap) * CGFloat(pos.spanCols))
                    .overlay(alignment: .leading) {
                        Text(pos.label)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }

    private var weekdayLabels: some View {
        VStack(spacing: gap) {
            ForEach(["S","M","T","W","T","F","S"], id: \.self) { d in
                Text(d)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 14, height: cellSize, alignment: .trailing)
            }
        }
    }

    private var weeksGrid: some View {
        HStack(alignment: .top, spacing: gap) {
            ForEach(weeks.indices, id: \.self) { wi in
                VStack(spacing: gap) {
                    ForEach(0..<7, id: \.self) { di in
                        let day = weeks[wi][di]
                        cell(for: day)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(for dateKey: String?) -> some View {
        if let key = dateKey {
            let s = vm.sessionsMap[key]
            RoundedRectangle(cornerRadius: 2)
                .fill(cellColor(session: s, dateKey: key))
                .frame(width: cellSize, height: cellSize)
                .opacity(key > DateHelpers.todayKey() ? 0.15 : 1)
                .help(tooltipText(session: s, dateKey: key))
        } else {
            Color.clear.frame(width: cellSize, height: cellSize)
        }
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("less")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
            ForEach(legendColors, id: \.self) { c in
                RoundedRectangle(cornerRadius: 2)
                    .fill(c)
                    .frame(width: cellSize, height: cellSize)
            }
            Text("more")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.blue.opacity(0.5))
                .frame(width: cellSize, height: cellSize)
                .padding(.leading, 6)
            Text("freeze")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 6)
    }

    // MARK: – Helpers

    private func cellColor(session: CodingSession?, dateKey: String) -> Color {
        guard let s = session else {
            return Color(.systemFill).opacity(0.4)
        }
        if s.freezeUsed { return .blue.opacity(0.45) }
        // Manual override (no GitHub verification) shown in yellow/muted
        let base: Color = s.manualOverride ? .yellow : .orange
        switch s.minutes {
        case 120...: return base
        case 90...:  return base.opacity(0.75)
        case 60...:  return base.opacity(0.55)
        case 30...:  return base.opacity(0.35)
        default:     return Color(.systemFill)
        }
    }

    private func tooltipText(session: CodingSession?, dateKey: String) -> String {
        guard let s = session else { return dateKey }
        if s.freezeUsed { return "\(dateKey): freeze" }
        return "\(dateKey): \(s.minutes) min"
    }

    private var legendColors: [Color] {
        [Color(.systemFill),
         .orange.opacity(0.30), .orange.opacity(0.50),
         .orange.opacity(0.75), .orange]
    }

    // MARK: – Grid layout helpers

    /// Cells padded to full weeks, grouped into columns of 7.
    private var weeks: [[String?]] {
        guard let first = days.first,
              let firstDate = DateHelpers.date(from: first) else { return [] }
        let startOffset = Calendar.current.component(.weekday, from: firstDate) - 1
        var cells: [String?] = Array(repeating: nil, count: startOffset) + days.map { Optional($0) }
        // pad end
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0+7]) }
    }

    struct MonthPosition { let label: String; let spanCols: Int }

    private var monthPositions: [MonthPosition] {
        var result: [MonthPosition] = []
        var currentMonth = ""
        var colStart = 0
        var colCount = 0
        for (wi, week) in weeks.enumerated() {
            let firstReal = week.compactMap { $0 }.first
            let month = firstReal.flatMap { DateHelpers.date(from: $0) }.map {
                ["Jan","Feb","Mar","Apr","May","Jun",
                 "Jul","Aug","Sep","Oct","Nov","Dec"][Calendar.current.component(.month, from: $0) - 1]
            } ?? ""
            if month != currentMonth {
                if !currentMonth.isEmpty {
                    result.append(MonthPosition(label: currentMonth, spanCols: colCount))
                }
                currentMonth = month; colStart = wi; colCount = 1
            } else {
                colCount += 1
            }
        }
        if !currentMonth.isEmpty {
            result.append(MonthPosition(label: currentMonth, spanCols: colCount))
        }
        return result
    }
}
