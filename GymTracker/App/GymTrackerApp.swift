import SwiftUI
import SwiftData

@main
struct GymTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let container: ModelContainer
    @State private var restTimer: RestTimerModel
    @State private var settings: AppSettings

    init() {
        let container = ModelContainerFactory.shared
        self.container = container
        SeedService.seedIfNeeded(context: container.mainContext)
        Self.removeDraftTemplates(context: container.mainContext)

        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _restTimer = State(initialValue: RestTimerModel(settings: settings))
    }

    /// Deletes unnamed routine drafts left behind if the app was terminated
    /// while the New Routine editor was open (drafts are inserted live and
    /// only get a name on Save).
    private static func removeDraftTemplates(context: ModelContext) {
        let emptyName = ""
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate<WorkoutTemplate> { $0.name == emptyName }
        )
        guard let drafts = try? context.fetch(descriptor), !drafts.isEmpty else { return }
        for draft in drafts {
            context.delete(draft)
        }
        try? context.save()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(restTimer)
                .environment(settings)
        }
        .modelContainer(container)
    }
}
