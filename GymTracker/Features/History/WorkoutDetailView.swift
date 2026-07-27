import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let workout: Workout

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var settings

    @State private var showingDeleteConfirmation = false
    @State private var showingSaveAsRoutine = false
    @State private var routineName = ""
    @State private var showingActiveWorkoutWarning = false

    var body: some View {
        // The workout can be swipe-deleted in History while this screen sits
        // on another tab's navigation stack; don't touch a deleted model.
        if workout.isDeleted {
            ContentUnavailableView(
                "Workout Deleted",
                systemImage: "trash",
                description: Text("This workout was removed.")
            )
        } else {
            detailContent
        }
    }

    private var detailContent: some View {
        List {
            Section {
                HStack(spacing: 8) {
                    StatCard(title: "Duration", value: Format.duration(seconds: workout.durationSeconds))
                    StatCard(title: "Sets", value: "\(workout.completedSetCount)")
                    StatCard(
                        title: "Volume",
                        value: workout.totalVolume > 0
                            ? Format.weight(workout.totalVolume, unit: settings.weightUnit)
                            : "—"
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            ForEach(workout.orderedExercises) { workoutExercise in
                Section(workoutExercise.exerciseName) {
                    ForEach(workoutExercise.orderedSets) { set in
                        HStack {
                            Text(set.isWarmup ? "W" : "\(workingSetNumber(of: set, in: workoutExercise))")
                                .font(.caption.monospacedDigit().bold())
                                .foregroundStyle(set.isWarmup ? Color.orange : Color.secondary)
                                .frame(width: 24)
                            Text("\(Format.plainWeight(set.weight)) \(settings.weightUnit.displayName) × \(set.reps)")
                                .monospacedDigit()
                            Spacer()
                            if set.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(workout.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        repeatWorkout()
                    } label: {
                        Label("Repeat Workout", systemImage: "arrow.counterclockwise")
                    }
                    Button {
                        routineName = workout.title == "Workout" ? "New Routine" : workout.title
                        showingSaveAsRoutine = true
                    } label: {
                        Label("Save as Routine", systemImage: "list.bullet.rectangle")
                    }
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Delete this workout?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                WorkoutFactory.delete(workout, context: context)
                WidgetDataStore.refresh(context: context)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Save as Routine", isPresented: $showingSaveAsRoutine) {
            TextField("Routine name", text: $routineName)
            Button("Save") {
                let trimmed = routineName.trimmingCharacters(in: .whitespaces)
                WorkoutFactory.makeTemplate(
                    from: workout,
                    name: trimmed.isEmpty ? "New Routine" : trimmed,
                    context: context
                )
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Workout in Progress", isPresented: $showingActiveWorkoutWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Finish or discard your current workout before starting a new one.")
        }
    }

    private func workingSetNumber(of set: SetEntry, in workoutExercise: WorkoutExercise) -> Int {
        let peers = workoutExercise.orderedSets.filter { !$0.isWarmup }
        return (peers.firstIndex(where: { $0 === set }) ?? set.orderIndex) + 1
    }

    private func repeatWorkout() {
        let activeCount = (try? context.fetchCount(
            FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.endDate == nil })
        )) ?? 0
        if activeCount > 0 {
            showingActiveWorkoutWarning = true
            return
        }
        WorkoutFactory.repeatWorkout(workout, context: context)
        router.selectedTab = .workout
    }
}
