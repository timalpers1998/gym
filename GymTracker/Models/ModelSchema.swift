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

/// V3 adds SetEffort (RIR logging). V1 and V2 are both released and frozen;
/// only additive changes via new entities are allowed.
enum GymSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

    static var models: [any PersistentModel.Type] {
        GymSchemaV2.models + [SetEffort.self]
    }
}

enum GymMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [GymSchemaV1.self, GymSchemaV2.self, GymSchemaV3.self, GymSchemaV4.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: GymSchemaV1.self, toVersion: GymSchemaV2.self),
            .lightweight(fromVersion: GymSchemaV2.self, toVersion: GymSchemaV3.self),
            .lightweight(fromVersion: GymSchemaV3.self, toVersion: GymSchemaV4.self),
        ]
    }
}

typealias Exercise = GymSchemaV4.Exercise
typealias WorkoutTemplate = GymSchemaV4.WorkoutTemplate
typealias TemplateExercise = GymSchemaV4.TemplateExercise
typealias TemplateSet = GymSchemaV4.TemplateSet
typealias Workout = GymSchemaV4.Workout
typealias WorkoutExercise = GymSchemaV4.WorkoutExercise
typealias SetEntry = GymSchemaV4.SetEntry
typealias BodyWeightEntry = GymSchemaV2.BodyWeightEntry
typealias SetEffort = GymSchemaV3.SetEffort
