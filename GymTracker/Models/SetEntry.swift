import Foundation
import SwiftData

extension GymSchemaV1 {
    @Model
    final class SetEntry {
        var orderIndex: Int = 0
        var reps: Int = 0
        var weight: Double = 0
        var isCompleted: Bool = false
        var completedAt: Date? = nil
        var isWarmup: Bool = false
        var workoutExercise: WorkoutExercise? = nil

        var volume: Double { Double(reps) * weight }

        init(orderIndex: Int, reps: Int = 0, weight: Double = 0, isWarmup: Bool = false) {
            self.orderIndex = orderIndex
            self.reps = reps
            self.weight = weight
            self.isWarmup = isWarmup
        }
    }
}
