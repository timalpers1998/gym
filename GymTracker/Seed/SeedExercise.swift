import Foundation

struct SeedExercise {
    let uuidString: String
    let name: String
    let muscleGroup: MuscleGroup
    let equipment: Equipment

    var uuid: UUID {
        UUID(uuidString: uuidString) ?? UUID()
    }
}
