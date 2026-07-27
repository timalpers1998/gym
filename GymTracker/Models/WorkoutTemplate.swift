import Foundation
import SwiftData

extension GymSchemaV1 {
    @Model
    final class WorkoutTemplate {
        var name: String = ""
        var notes: String = ""
        var createdAt: Date = Date.now
        var lastUsedAt: Date? = nil

        @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
        var exercises: [TemplateExercise]? = nil

        @Relationship(deleteRule: .nullify, inverse: \Workout.sourceTemplate)
        var workouts: [Workout]? = nil

        var orderedExercises: [TemplateExercise] {
            (exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        }

        init(name: String, notes: String = "") {
            self.name = name
            self.notes = notes
            self.createdAt = Date.now
        }
    }
}
