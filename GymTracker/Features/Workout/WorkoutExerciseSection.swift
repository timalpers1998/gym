import SwiftUI
import SwiftData

struct WorkoutExerciseSection: View {
    let workoutExercise: WorkoutExercise

    @Environment(\.modelContext) private var context

    var body: some View {
        Section {
            ForEach(workoutExercise.orderedSets) { set in
                SetRowView(set: set)
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
            HStack {
                Text(workoutExercise.exerciseName)
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
