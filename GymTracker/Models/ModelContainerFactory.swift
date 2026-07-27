import Foundation
import SwiftData

enum ModelContainerFactory {
    static func make(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(versionedSchema: GymSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: GymMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError(
                "Failed to create ModelContainer: \(error). "
                + "If the schema changed during development, delete the app from the device/simulator and reinstall."
            )
        }
    }
}
