import Foundation
import SwiftData

enum ModelContainerFactory {
    static func make(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(versionedSchema: GymSchemaV3.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: GymMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError(
                "GymTracker couldn't open its database: \(error). "
                + "Try relaunching; if this persists, reinstall the app "
                + "(a CSV export from Settings is the data backstop)."
            )
        }
    }
}
