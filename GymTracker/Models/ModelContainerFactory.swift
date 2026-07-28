import Foundation
import SwiftData

enum ModelContainerFactory {
    /// The app's one on-disk container. App Intents may run before or without
    /// the SwiftUI scene, so both go through this shared instance instead of
    /// opening the store twice.
    static let shared = make()

    static func make(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(versionedSchema: GymSchemaV5.self)
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
