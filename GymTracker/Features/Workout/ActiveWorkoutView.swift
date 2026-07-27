import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    let workout: Workout

    @Environment(\.modelContext) private var context
    @Environment(RestTimerModel.self) private var restTimer

    @State private var showingExercisePicker = false
    @State private var showingCancelConfirmation = false
    @State private var showingFinishDialog = false
    @State private var showingSaveAsRoutine = false
    @State private var routineName = ""

    var body: some View {
        List {
            Section {
                TimelineView(.periodic(from: workout.startDate, by: 1)) { timeline in
                    let elapsed = max(0, Int(timeline.date.timeIntervalSince(workout.startDate)))
                    HStack {
                        Label(Format.duration(seconds: elapsed), systemImage: "clock")
                            .font(.title3.monospacedDigit().bold())
                        Spacer()
                        Text("\(workout.completedSetCount) sets done")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(workout.orderedExercises) { workoutExercise in
                WorkoutExerciseSection(workoutExercise: workoutExercise)
            }

            Section {
                Button {
                    showingExercisePicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if restTimer.endDate != nil {
                RestTimerBar()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", role: .destructive) {
                    showingCancelConfirmation = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Finish") {
                    showingFinishDialog = true
                }
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView { exercises in
                for exercise in exercises {
                    WorkoutFactory.addExercise(exercise, to: workout, context: context)
                }
                try? context.save()
            }
        }
        .confirmationDialog(
            "Discard this workout?",
            isPresented: $showingCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Workout", role: .destructive) {
                cancelWorkout()
            }
            Button("Keep Going", role: .cancel) {}
        }
        .confirmationDialog(
            "Finish workout?",
            isPresented: $showingFinishDialog,
            titleVisibility: .visible
        ) {
            Button("Finish") {
                finishWorkout()
            }
            if workout.sourceTemplate == nil && !workout.orderedExercises.isEmpty {
                Button("Finish & Save as Routine") {
                    routineName = workout.title == "Workout" ? "New Routine" : workout.title
                    showingSaveAsRoutine = true
                }
            }
            Button("Keep Going", role: .cancel) {}
        }
        .alert("Save as Routine", isPresented: $showingSaveAsRoutine) {
            TextField("Routine name", text: $routineName)
            Button("Save & Finish") {
                let trimmed = routineName.trimmingCharacters(in: .whitespaces)
                WorkoutFactory.makeTemplate(
                    from: workout,
                    name: trimmed.isEmpty ? "New Routine" : trimmed,
                    context: context
                )
                finishWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The exercises and sets from this workout become a reusable routine.")
        }
    }

    private func finishWorkout() {
        restTimer.skip()
        WorkoutFactory.finish(workout, context: context)
    }

    private func cancelWorkout() {
        restTimer.skip()
        context.delete(workout)
        try? context.save()
    }
}
