import WidgetKit
import SwiftUI

struct StatsEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSummary?
}

struct StatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: Date.now, summary: Self.sampleSummary)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        completion(StatsEntry(date: Date.now, summary: loadSummary() ?? Self.sampleSummary))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        // The app reloads timelines whenever the data changes; the .after
        // policy additionally re-renders at the week rollover so "This Week"
        // can't stay stale if the app isn't opened.
        let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date.now)

        var summary = loadSummary()
        if var stale = summary, let weekInterval, stale.generatedAt < weekInterval.start {
            stale.weekCount = 0
            stale.weekDays = [Bool](repeating: false, count: 7)
            summary = stale
        }

        let entry = StatsEntry(date: Date.now, summary: summary)
        let policy: TimelineReloadPolicy = weekInterval.map { .after($0.end) } ?? .never
        completion(Timeline(entries: [entry], policy: policy))
    }

    private func loadSummary() -> WidgetSummary? {
        guard let defaults = UserDefaults(suiteName: WidgetShared.appGroupID),
              let data = defaults.data(forKey: WidgetShared.summaryKey)
        else { return nil }
        return try? JSONDecoder().decode(WidgetSummary.self, from: data)
    }

    static let sampleSummary = WidgetSummary(
        weekCount: 3,
        weekStreak: 5,
        lastWorkoutTitle: "Push Day",
        lastWorkoutDate: Date.now,
        weekDays: [true, false, true, false, true, false, false],
        generatedAt: Date.now
    )
}

struct StatsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GymTrackerStats", provider: StatsProvider()) { entry in
            StatsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Workout Stats")
        .description("This week's workouts, streak, and last session.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct StatsWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: StatsEntry

    var body: some View {
        if let summary = entry.summary {
            switch family {
            case .systemMedium:
                MediumStatsView(summary: summary)
            default:
                SmallStatsView(summary: summary)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Open GymTracker to get started")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SmallStatsView: View {
    let summary: WidgetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("This Week", systemImage: "dumbbell.fill")
                .font(.caption.bold())
                .foregroundStyle(.orange)
            Text("\(summary.weekCount)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("workout\(summary.weekCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if summary.weekStreak > 0 {
                Label("\(summary.weekStreak) week streak", systemImage: "flame.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct MediumStatsView: View {
    let summary: WidgetSummary

    private var daySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label("This Week", systemImage: "dumbbell.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                Text("\(summary.weekCount)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                if summary.weekStreak > 0 {
                    Label("\(summary.weekStreak) wk streak", systemImage: "flame.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { index in
                        VStack(spacing: 3) {
                            Text(index < daySymbols.count ? daySymbols[index] : "")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Circle()
                                .fill(summary.weekDays.indices.contains(index) && summary.weekDays[index]
                                      ? Color.orange
                                      : Color.secondary.opacity(0.25))
                                .frame(width: 10, height: 10)
                        }
                    }
                }
                if let title = summary.lastWorkoutTitle, let date = summary.lastWorkoutDate {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Last: \(title)")
                            .font(.caption)
                            .lineLimit(1)
                        Text(date.formatted(.dateTime.weekday().day().month()))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
