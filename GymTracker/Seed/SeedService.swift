import Foundation
import SwiftData

@MainActor
enum SeedService {
    /// Bump when appending new entries to ExerciseSeedData.
    static let seedVersion = 1

    private static let seedVersionKey = "exerciseSeedVersion"

    /// Inserts any missing built-in exercises. Matches on UUID and never
    /// overwrites existing rows, so user edits and archives are preserved and
    /// re-running is always safe.
    static func seedIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: seedVersionKey) < seedVersion else { return }

        do {
            let existing = try context.fetch(FetchDescriptor<Exercise>())
            let existingUUIDs = Set(existing.map(\.uuid))

            for seed in ExerciseSeedData.all where !existingUUIDs.contains(seed.uuid) {
                let exercise = Exercise(
                    uuid: seed.uuid,
                    name: seed.name,
                    muscleGroup: seed.muscleGroup,
                    equipment: seed.equipment,
                    measurement: seed.measurement
                )
                context.insert(exercise)
            }

            try context.save()
            defaults.set(seedVersion, forKey: seedVersionKey)
        } catch {
            // Leave the stored version unchanged so seeding retries next launch.
            print("Exercise seeding failed: \(error)")
        }
    }
}
