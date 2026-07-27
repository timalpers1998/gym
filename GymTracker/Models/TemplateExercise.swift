import Foundation
import SwiftData

extension GymSchemaV1 {
    @Model
    final class TemplateExercise {
        var orderIndex: Int = 0
        var exerciseName: String = ""
        var exerciseUUID: UUID? = nil
        var exercise: Exercise? = nil
        var template: WorkoutTemplate? = nil

        @Relationship(deleteRule: .cascade, inverse: \TemplateSet.templateExercise)
        var plannedSets: [TemplateSet]? = nil

        var orderedSets: [TemplateSet] {
            (plannedSets ?? []).sorted { $0.orderIndex < $1.orderIndex }
        }

        init(orderIndex: Int, exercise: Exercise) {
            self.orderIndex = orderIndex
            self.exercise = exercise
            self.exerciseName = exercise.name
            self.exerciseUUID = exercise.uuid
        }
    }
}
