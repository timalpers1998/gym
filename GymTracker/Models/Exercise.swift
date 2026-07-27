import Foundation
import SwiftData

extension GymSchemaV1 {
    @Model
    final class Exercise {
        var uuid: UUID = UUID()
        var name: String = ""
        var muscleGroupRaw: String = MuscleGroup.other.rawValue
        var equipmentRaw: String = Equipment.other.rawValue
        var isCustom: Bool = false
        var isArchived: Bool = false
        var notes: String = ""
        var createdAt: Date = Date.now

        @Relationship(deleteRule: .nullify, inverse: \TemplateExercise.exercise)
        var templateExercises: [TemplateExercise]? = nil

        @Relationship(deleteRule: .nullify, inverse: \WorkoutExercise.exercise)
        var workoutExercises: [WorkoutExercise]? = nil

        var muscleGroup: MuscleGroup {
            get { MuscleGroup(rawValue: muscleGroupRaw) ?? .other }
            set { muscleGroupRaw = newValue.rawValue }
        }

        var equipment: Equipment {
            get { Equipment(rawValue: equipmentRaw) ?? .other }
            set { equipmentRaw = newValue.rawValue }
        }

        init(
            uuid: UUID = UUID(),
            name: String,
            muscleGroup: MuscleGroup,
            equipment: Equipment = .other,
            isCustom: Bool = false,
            notes: String = ""
        ) {
            self.uuid = uuid
            self.name = name
            self.muscleGroupRaw = muscleGroup.rawValue
            self.equipmentRaw = equipment.rawValue
            self.isCustom = isCustom
            self.notes = notes
            self.createdAt = Date.now
        }
    }
}
