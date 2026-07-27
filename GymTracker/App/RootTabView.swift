import SwiftUI
import UserNotifications

struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @State private var router = AppRouter()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack {
                WorkoutTabView()
            }
            .tabItem {
                Label("Workout", systemImage: "dumbbell.fill")
            }
            .tag(AppTab.workout)

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "calendar")
            }
            .tag(AppTab.history)

            NavigationStack {
                ExerciseLibraryView()
            }
            .tabItem {
                Label("Exercises", systemImage: "figure.strengthtraining.traditional")
            }
            .tag(AppTab.exercises)

            NavigationStack {
                ProgressTabView()
            }
            .tabItem {
                Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(AppTab.progress)
        }
        .environment(router)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                WidgetDataStore.refresh(context: context)
            }
        }
    }
}

enum AppTab: Hashable {
    case workout, history, exercises, progress
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .workout
}
