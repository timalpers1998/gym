import Foundation
import SwiftData

extension GymSchemaV1 {
    @Model
    final class WorkoutExercise {
        var orderIndex: Int = 0
        var exerciseName: String = ""
        var exerciseUUID: UUID? = nil
        var notes: String = ""
        var exercise: Exercise? = nil
        var workout: Workout? = nil

        @Relationship(deleteRule: .cascade, inverse: \SetEntry.workoutExercise)
        var sets: [SetEntry]? = nil

        var orderedSets: [SetEntry] {
            (sets ?? []).sorted { $0.orderIndex < $1.orderIndex }
        }

        var completedSets: [SetEntry] {
            (sets ?? []).filter(\.isCompleted)
        }

        /// Completed working sets only, matching how ProgressCalculator counts.
        var totalVolume: Double {
            completedSets.filter { !$0.isWarmup }.reduce(0) { $0 + $1.volume }
        }

        init(orderIndex: Int, exercise: Exercise) {
            self.orderIndex = orderIndex
            self.exercise = exercise
            self.exerciseName = exercise.name
            self.exerciseUUID = exercise.uuid
        }

        init(orderIndex: Int, exerciseName: String, exerciseUUID: UUID?) {
            self.orderIndex = orderIndex
            self.exerciseName = exerciseName
            self.exerciseUUID = exerciseUUID
        }
    }
}
