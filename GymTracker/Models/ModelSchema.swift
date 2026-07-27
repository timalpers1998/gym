import Foundation
import SwiftData

enum GymSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Exercise.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            TemplateSet.self,
            Workout.self,
            WorkoutExercise.self,
            SetEntry.self,
        ]
    }
}

enum GymMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [GymSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

typealias Exercise = GymSchemaV1.Exercise
typealias WorkoutTemplate = GymSchemaV1.WorkoutTemplate
typealias TemplateExercise = GymSchemaV1.TemplateExercise
typealias TemplateSet = GymSchemaV1.TemplateSet
typealias Workout = GymSchemaV1.Workout
typealias WorkoutExercise = GymSchemaV1.WorkoutExercise
typealias SetEntry = GymSchemaV1.SetEntry
