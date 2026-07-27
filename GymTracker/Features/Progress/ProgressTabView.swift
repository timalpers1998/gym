import SwiftUI
import SwiftData
import Charts

struct ProgressTabView: View {
    @Query(filter: #Predicate<Workout> { $0.endDate != nil }, sort: \Workout.startDate, order: .reverse)
    private var workouts: [Workout]

    @Query private var allEntries: [WorkoutExercise]

    @Environment(AppSettings.self) private var settings

    private var weeklyCounts: [WeeklyCount] {
        ProgressCalculator.weeklyCounts(workouts: workouts, weeks: 12)
    }

    private var thisWeekCount: Int {
        weeklyCounts.last?.count ?? 0
    }

    private var recentPRs: [RecentPR] {
        ProgressCalculator.recentPRs(entries: allEntries, limit: 5)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 8) {
                    StatCard(title: "Workouts", value: "\(workouts.count)")
                    StatCard(title: "This Week", value: "\(thisWeekCount)")
                    StatCard(
                        title: "Week Streak",
                        value: "\(ProgressCalculator.weeklyStreak(workouts: workouts))"
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Workouts per Week") {
                if workouts.isEmpty {
                    Text("Finish a workout to start building your chart.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Chart(weeklyCounts) { week in
                        BarMark(
                            x: .value("Week", week.weekStart, unit: .weekOfYear),
                            y: .value("Workouts", week.count)
                        )
                        .cornerRadius(3)
                    }
                    .frame(height: 180)
                    .padding(.vertical, 4)
                }
            }

            BodyWeightSection()

            Section("Recent PRs") {
                if recentPRs.isEmpty {
                    Text("Personal records appear once you log completed sets with weight.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentPRs) { pr in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pr.exerciseName)
                                    .font(.subheadline)
                                Text(pr.date.formatted(.dateTime.day().month().year()))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Format.weight(pr.weight, unit: settings.weightUnit)) × \(pr.reps)")
                                .font(.subheadline.bold())
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle("Progress")
    }
}
