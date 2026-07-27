import SwiftUI
import SwiftData

/// Plain-value copy of a previous session's set. Snapshotting (instead of
/// holding SetEntry references) keeps the hints safe to render even if the
/// source workout is deleted from History mid-session.
struct LastSetSnapshot {
    let weight: Double
    let reps: Int
    let isCompleted: Bool
    let isWarmup: Bool
}

struct WorkoutExerciseSection: View {
    let workoutExercise: WorkoutExercise

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    /// The same exercise's sets from the most recent finished workout,
    /// used for the "last time" header line and field placeholders.
    @State private var lastSets: [LastSetSnapshot] = []

    var body: some View {
        Section {
            ForEach(workoutExercise.orderedSets) { set in
                SetRowView(set: set, lastSet: lastSet(for: set), suggestion: suggestion(for: set))
            }
            .onDelete { offsets in
                deleteSets(at: offsets)
            }

            Button {
                WorkoutFactory.addSet(to: workoutExercise, context: context)
            } label: {
                Label("Add Set", systemImage: "plus.circle")
                    .font(.subheadline)
            }
        } header: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workoutExercise.exerciseName)
                    if let lastSummary {
                        Text(lastSummary)
                            .font(.caption2)
                            .textCase(nil)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Menu {
                    if let uuid = workoutExercise.exerciseUUID {
                        progressionStepPicker(uuid: uuid)
                    }
                    Button(role: .destructive) {
                        removeExercise()
                    } label: {
                        Label("Remove Exercise", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            loadLastSets()
        }
    }

    private var lastSummary: String? {
        let completed = lastSets.filter(\.isCompleted)
        guard !completed.isEmpty else { return nil }
        let sets = completed
            .map { "\(Format.plainWeight($0.weight))×\($0.reps)" }
            .joined(separator: " · ")
        return "Last: \(sets)"
    }

    private func lastSet(for set: SetEntry) -> LastSetSnapshot? {
        let index = set.orderIndex
        guard index >= 0 && index < lastSets.count else { return nil }
        return lastSets[index]
    }

    private func progressionStepPicker(uuid: UUID) -> some View {
        let choices: [Double] = settings.weightUnit == .lb
            ? [1, 2.5, 5, 10]
            : [0.5, 1, 1.25, 2.5, 5]
        return Picker(selection: Binding(
            get: { settings.progressionStep(for: uuid) },
            set: { settings.setProgressionStep($0, for: uuid) }
        )) {
            ForEach(choices, id: \.self) { step in
                Text("\(Format.plainWeight(step)) \(settings.weightUnit.displayName)").tag(step)
            }
        } label: {
            Label("Progression Step", systemImage: "chart.line.uptrend.xyaxis")
        }
        .pickerStyle(.menu)
    }

    /// Target for the next pending working set: the smallest estimated-10RM
    /// increase over last session's corresponding set. Other rows get nil.
    private func suggestion(for set: SetEntry) -> ProgressionSuggestion? {
        guard !set.isCompleted, !set.isWarmup else { return nil }
        guard let current = workoutExercise.orderedSets.first(where: { !$0.isCompleted && !$0.isWarmup }),
              current === set else { return nil }
        guard let baseline = lastSet(for: set),
              baseline.isCompleted, !baseline.isWarmup, baseline.reps > 0 else { return nil }
        return ProgressionCalculator.nextProgression(
            lastWeight: baseline.weight,
            lastReps: baseline.reps,
            increment: settings.progressionStep(for: workoutExercise.exerciseUUID),
            allowIncrease: allowIncrease(before: set)
        )
    }

    /// A completed set this session that fell short of its own last-session
    /// baseline holds the next target at last session's numbers.
    private func allowIncrease(before set: SetEntry) -> Bool {
        let previous = workoutExercise.orderedSets
            .filter { $0.isCompleted && !$0.isWarmup && $0.orderIndex < set.orderIndex }
            .max { $0.orderIndex < $1.orderIndex }
        guard let previous,
              let baseline = lastSet(for: previous),
              baseline.isCompleted, !baseline.isWarmup, baseline.reps > 0 else { return true }
        if baseline.weight <= 0 {
            return previous.reps >= baseline.reps
        }
        let achieved = ProgressionCalculator.estimatedTenRepMax(weight: previous.weight, reps: previous.reps)
        let target = ProgressionCalculator.estimatedTenRepMax(weight: baseline.weight, reps: baseline.reps)
        return achieved >= target - 0.05
    }

    private func loadLastSets() {
        guard let uuid = workoutExercise.exerciseUUID else { return }
        let id: UUID? = uuid
        let descriptor = FetchDescriptor<WorkoutExercise>(
            predicate: #Predicate<WorkoutExercise> { $0.exerciseUUID == id }
        )
        guard let entries = try? context.fetch(descriptor) else { return }

        let currentWorkout = workoutExercise.workout
        let previous = entries
            .filter { entry in
                entry.workout?.endDate != nil && entry.workout !== currentWorkout
            }
            .max { ($0.workout?.startDate ?? .distantPast) < ($1.workout?.startDate ?? .distantPast) }
        lastSets = (previous?.orderedSets ?? []).map { set in
            LastSetSnapshot(
                weight: set.weight,
                reps: set.reps,
                isCompleted: set.isCompleted,
                isWarmup: set.isWarmup
            )
        }
    }

    private func deleteSets(at offsets: IndexSet) {
        let ordered = workoutExercise.orderedSets
        for index in offsets {
            context.delete(ordered[index])
        }
        let remaining = ordered.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)
        for (index, set) in remaining.enumerated() {
            set.orderIndex = index
        }
    }

    private func removeExercise() {
        guard let workout = workoutExercise.workout else {
            context.delete(workoutExercise)
            return
        }
        context.delete(workoutExercise)
        let remaining = workout.orderedExercises.filter { $0 !== workoutExercise }
        for (index, exercise) in remaining.enumerated() {
            exercise.orderIndex = index
        }
    }
}
