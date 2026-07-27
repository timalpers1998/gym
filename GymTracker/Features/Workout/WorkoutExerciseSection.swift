import SwiftUI
import SwiftData

struct WorkoutExerciseSection: View {
    let workoutExercise: WorkoutExercise

    @Environment(\.modelContext) private var context

    /// The same exercise's sets from the most recent finished workout,
    /// used for the "last time" header line and field placeholders.
    @State private var lastSets: [SetEntry] = []

    var body: some View {
        Section {
            ForEach(workoutExercise.orderedSets) { set in
                SetRowView(set: set, lastSet: lastSet(for: set))
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

    private func lastSet(for set: SetEntry) -> SetEntry? {
        let index = set.orderIndex
        guard index >= 0 && index < lastSets.count else { return nil }
        return lastSets[index]
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
        lastSets = previous?.orderedSets ?? []
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
