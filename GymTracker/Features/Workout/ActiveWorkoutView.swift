import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    let workout: Workout

    @Environment(\.modelContext) private var context
    @Environment(RestTimerModel.self) private var restTimer

    @State private var showingExercisePicker = false
    @State private var showingCancelConfirmation = false
    @State private var showingFinishSheet = false

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
                    showingFinishSheet = true
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
        .sheet(isPresented: $showingFinishSheet) {
            FinishWorkoutSheet(workout: workout) { saveAsRoutine, routineName in
                if saveAsRoutine {
                    let trimmed = routineName.trimmingCharacters(in: .whitespaces)
                    WorkoutFactory.makeTemplate(
                        from: workout,
                        name: trimmed.isEmpty ? "New Routine" : trimmed,
                        context: context
                    )
                }
                showingFinishSheet = false
                finishWorkout()
            }
        }
        .onAppear {
            // Clear a rest timer that expired while another tab was showing.
            if let end = restTimer.endDate, end <= Date.now {
                restTimer.finish()
            }
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

private struct FinishWorkoutSheet: View {
    let workout: Workout
    let onFinish: (_ saveAsRoutine: Bool, _ routineName: String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var saveAsRoutine = false
    @State private var routineName = ""

    private var canSaveAsRoutine: Bool {
        workout.sourceTemplate == nil && !workout.orderedExercises.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(
                        "Duration",
                        value: Format.duration(seconds: max(0, Int(Date.now.timeIntervalSince(workout.startDate))))
                    )
                    LabeledContent("Completed sets", value: "\(workout.completedSetCount)")
                }

                if canSaveAsRoutine {
                    Section {
                        Toggle("Save as routine", isOn: $saveAsRoutine)
                        if saveAsRoutine {
                            TextField("Routine name", text: $routineName)
                        }
                    } footer: {
                        Text("Saves this workout's exercises and sets as a reusable routine.")
                    }
                }

                Section {
                    Button {
                        onFinish(saveAsRoutine, routineName)
                    } label: {
                        Text("Finish Workout")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Finish Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Keep Going") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                routineName = workout.title == "Workout" ? "" : workout.title
            }
        }
        .presentationDetents([.medium, .large])
    }
}
