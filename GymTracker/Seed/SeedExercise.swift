import Foundation

struct SeedExercise {
    let uuidString: String
    let name: String
    let muscleGroup: MuscleGroup
    let equipment: Equipment
    var measurement: ExerciseMeasurement = .reps

    var uuid: UUID {
        UUID(uuidString: uuidString) ?? UUID()
    }
}
