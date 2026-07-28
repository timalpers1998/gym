import SwiftUI
import SwiftData
import Charts

struct ProgressTabView: View {
    @Query(filter: #Predicate<Workout> { $0.endDate != nil }, sort: \Workout.startDate, order: .reverse)
    private var workouts: [Workout]

    @Query private var allEntries: [WorkoutExercise]

    @Query private var exercises: [Exercise]

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

    private var muscleVolumes: [MuscleWeekVolume] {
        ProgressCalculator.muscleWeekVolumes(entries: allEntries)
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

            if !muscleVolumes.isEmpty {
                Section("Sets per Muscle · This Week") {
                    ForEach(muscleVolumes) { volume in
                        HStack(spacing: 12) {
                            Text(volume.group.displayName)
                                .font(.subheadline)
                                .frame(width: 88, alignment: .leading)
                            ProgressView(value: min(1, Double(volume.thisWeek) / 20))
                                .tint(volumeTint(for: volume.thisWeek))
                            Text("\(volume.thisWeek)")
                                .font(.subheadline.bold())
                                .monospacedDigit()
                                .frame(width: 28, alignment: .trailing)
                            Text("Ø \(volume.weeklyAverage.formatted(.number.precision(.fractionLength(0...1))))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                }
            }

            BodyWeightSection()

            MeasurementsSection()

            ProgressPhotosSection()

            Section("Recent PRs") {
                if recentPRs.isEmpty {
                    Text("Personal records appear once you log completed sets with weight.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentPRs) { pr in
                        if let exercise = exercise(for: pr) {
                            NavigationLink {
                                ExerciseDetailView(exercise: exercise)
                            } label: {
                                prRow(pr)
                            }
                        } else {
                            prRow(pr)
                        }
                    }
                }
            }
        }
        .navigationTitle("Progress")
    }

    /// Tint against the ~10–20 hard-sets-per-week hypertrophy landmark.
    private func volumeTint(for sets: Int) -> Color {
        if sets < 10 { return .orange }
        if sets <= 20 { return .green }
        return .red
    }

    private func exercise(for pr: RecentPR) -> Exercise? {
        guard let uuid = pr.exerciseUUID else { return nil }
        return exercises.first { $0.uuid == uuid }
    }

    private func prRow(_ pr: RecentPR) -> some View {
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
