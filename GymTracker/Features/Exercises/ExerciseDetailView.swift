import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    @Query private var history: [WorkoutExercise]

    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false

    init(exercise: Exercise) {
        self.exercise = exercise
        let id: UUID? = exercise.uuid
        _history = Query(filter: #Predicate<WorkoutExercise> { $0.exerciseUUID == id })
    }

    private var dataPoints: [ExerciseDataPoint] {
        ProgressCalculator.dataPoints(for: history)
    }

    private var recentEntries: [WorkoutExercise] {
        history
            .filter { $0.workout?.endDate != nil }
            .sorted { ($0.workout?.startDate ?? .distantPast) > ($1.workout?.startDate ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 8) {
                    MuscleGroupBadge(muscleGroup: exercise.muscleGroup)
                    Text(exercise.equipment.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if !exercise.notes.isEmpty {
                    Text(exercise.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if exercise.measurement == .reps,
               let records = ProgressCalculator.personalRecords(for: history) {
                Section("Personal Records") {
                    HStack(spacing: 8) {
                        StatCard(
                            title: "Heaviest Set",
                            value: Format.weight(records.heaviestWeight, unit: settings.weightUnit),
                            subtitle: "×\(records.heaviestWeightReps) · \(records.heaviestWeightDate.formatted(.dateTime.day().month()))"
                        )
                        StatCard(
                            title: "Est. 1RM",
                            value: Format.weight(records.bestE1RM, unit: settings.weightUnit),
                            subtitle: records.bestE1RMDate.formatted(.dateTime.day().month())
                        )
                        StatCard(
                            title: "Best Volume",
                            value: Format.weight(records.bestSessionVolume, unit: settings.weightUnit),
                            subtitle: records.bestSessionVolumeDate.formatted(.dateTime.day().month())
                        )
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            Section("Progress") {
                if dataPoints.count >= 2 {
                    ExerciseChartsView(dataPoints: dataPoints, measurement: exercise.measurement)
                } else {
                    Text("Log this exercise in at least two workouts to see progress charts.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !recentEntries.isEmpty {
                Section("Recent Workouts") {
                    ForEach(recentEntries) { entry in
                        if let workout = entry.workout {
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                entryRow(entry)
                            }
                        } else {
                            entryRow(entry)
                        }
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button {
                        exercise.isArchived.toggle()
                        try? context.save()
                    } label: {
                        Label(
                            exercise.isArchived ? "Unarchive" : "Archive",
                            systemImage: "archivebox"
                        )
                    }
                    if exercise.isCustom {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            ExerciseEditorView(exercise: exercise)
        }
        .confirmationDialog(
            "Delete this exercise?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                context.delete(exercise)
                try? context.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Past workouts keep their logged sets. Consider archiving instead to hide it from pickers.")
        }
    }

    private func entryRow(_ entry: WorkoutExercise) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.workout?.startDate.formatted(.dateTime.weekday().day().month().year()) ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(setsSummary(for: entry))
                .font(.subheadline)
                .monospacedDigit()
        }
    }

    private func setsSummary(for entry: WorkoutExercise) -> String {
        let sets = entry.orderedSets.filter(\.isCompleted)
        guard !sets.isEmpty else { return "No completed sets" }
        if exercise.measurement == .duration {
            return sets
                .map { Format.duration(seconds: $0.durationSeconds) }
                .joined(separator: "  ")
        }
        return sets
            .map { "\(Format.plainWeight($0.weight))×\($0.reps)" }
            .joined(separator: "  ")
    }
}
