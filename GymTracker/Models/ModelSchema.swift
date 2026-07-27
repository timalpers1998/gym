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

/// V2 adds BodyWeightEntry. The V1 model classes are frozen and reused —
/// SwiftData identifies schema versions by a checksum of the model structure,
/// so the released store still matches V1 and the added entity makes V2
/// distinct. Never change GymSchemaV1.models.
enum GymSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        GymSchemaV1.models + [BodyWeightEntry.self]
    }
}

enum GymMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [GymSchemaV1.self, GymSchemaV2.self] }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: GymSchemaV1.self, toVersion: GymSchemaV2.self)]
    }
}

typealias Exercise = GymSchemaV1.Exercise
typealias WorkoutTemplate = GymSchemaV1.WorkoutTemplate
typealias TemplateExercise = GymSchemaV1.TemplateExercise
typealias TemplateSet = GymSchemaV1.TemplateSet
typealias Workout = GymSchemaV1.Workout
typealias WorkoutExercise = GymSchemaV1.WorkoutExercise
typealias SetEntry = GymSchemaV1.SetEntry
typealias BodyWeightEntry = GymSchemaV2.BodyWeightEntry
