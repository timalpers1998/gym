import Foundation
import SwiftData

extension GymSchemaV1 {
    @Model
    final class Workout {
        var startDate: Date = Date.now
        var endDate: Date? = nil
        var durationSeconds: Int = 0
        var title: String = "Workout"
        var notes: String = ""
        var sourceTemplate: WorkoutTemplate? = nil

        @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
        var exercises: [WorkoutExercise]? = nil

        var orderedExercises: [WorkoutExercise] {
            (exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        }

        var isActive: Bool { endDate == nil }

        var completedSetCount: Int {
            (exercises ?? []).reduce(0) { count, exercise in
                count + (exercise.sets ?? []).filter(\.isCompleted).count
            }
        }

        var totalVolume: Double {
            (exercises ?? []).reduce(0) { $0 + $1.totalVolume }
        }

        init(title: String = "Workout", startDate: Date = Date.now, sourceTemplate: WorkoutTemplate? = nil) {
            self.title = title
            self.startDate = startDate
            self.sourceTemplate = sourceTemplate
        }
    }
}
