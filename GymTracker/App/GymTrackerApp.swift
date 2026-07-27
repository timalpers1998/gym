import SwiftUI
import SwiftData

@main
struct GymTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let container: ModelContainer
    @State private var restTimer: RestTimerModel
    @State private var settings: AppSettings

    init() {
        let container = ModelContainerFactory.make()
        self.container = container
        SeedService.seedIfNeeded(context: container.mainContext)

        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _restTimer = State(initialValue: RestTimerModel(settings: settings))
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
