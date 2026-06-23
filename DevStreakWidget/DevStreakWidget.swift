import WidgetKit
import SwiftUI

// MARK: – Timeline entry

struct DevStreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let todayDone: Bool
    let todayFreeze: Bool
    let seasonScore: Int
}

// MARK: – Provider

struct DevStreakProvider: TimelineProvider {

    private var defaults: UserDefaults {
        UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    func placeholder(in context: Context) -> DevStreakEntry {
        DevStreakEntry(date: Date(), streak: 7, todayDone: false, todayFreeze: false, seasonScore: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (DevStreakEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DevStreakEntry>) -> Void) {
        // Refresh at midnight and at midday
        let now      = Date()
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
        let midday   = Calendar.current.startOfDay(for: now).addingTimeInterval(43200)
        let next     = now < midday ? midday : midnight
        completion(Timeline(entries: [entry()], policy: .after(next)))
    }

    private func entry() -> DevStreakEntry {
        DevStreakEntry(
            date:        Date(),
            streak:      defaults.integer(forKey: "widget_streak"),
            todayDone:   defaults.bool(forKey: "widget_todayDone"),
            todayFreeze: defaults.bool(forKey: "widget_todayFreeze"),
            seasonScore: defaults.integer(forKey: "widget_seasonScore")
        )
    }
}

// MARK: – Widget views

struct DevStreakWidgetEntryView: View {
    var entry: DevStreakEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemMedium: mediumView
        default: smallView
        }
    }

    // Small: streak number + today dot
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("🔥")
                Spacer()
                todayDot
            }
            Spacer()
            Text("\(entry.streak)")
                .font(.system(size: 44, weight: .black, design: .monospaced))
                .foregroundStyle(entry.streak > 0 ? .orange : .secondary)
            Text("day streak")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding()
        .containerBackground(.background, for: .widget)
    }

    // Medium: streak + season score + today status
    private var mediumView: some View {
        HStack(spacing: 0) {
            // Left: streak
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text("🔥"); Spacer(); todayDot }
                Spacer()
                Text("\(entry.streak)")
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundStyle(entry.streak > 0 ? .orange : .secondary)
                Text("day streak")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().padding(.vertical, 8)

            // Right: season score + today label
            VStack(alignment: .leading, spacing: 4) {
                Text("SEASON")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("\(entry.seasonScore)")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                Spacer()
                todayLabel
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .containerBackground(.background, for: .widget)
    }

    @ViewBuilder
    private var todayDot: some View {
        Circle()
            .fill(entry.todayFreeze ? Color.blue :
                  entry.todayDone  ? Color.green : Color(.systemFill))
            .frame(width: 10, height: 10)
    }

    @ViewBuilder
    private var todayLabel: some View {
        if entry.todayFreeze {
            Label("Freeze used", systemImage: "snowflake").foregroundStyle(.blue)
        } else if entry.todayDone {
            Label("Done today", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        } else {
            Label("Not logged yet", systemImage: "circle").foregroundStyle(.secondary)
        }
    }
}

// MARK: – Widget declaration

@main
struct DevStreakWidget: Widget {
    let kind = "DevStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DevStreakProvider()) { entry in
            DevStreakWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("DevStreak")
        .description("Your coding streak at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
