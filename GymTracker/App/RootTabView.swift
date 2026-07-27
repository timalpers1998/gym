import SwiftUI
import UserNotifications

struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Environment(RestTimerModel.self) private var restTimer
    @State private var router = AppRouter()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack {
                WorkoutTabView()
            }
            .safeAreaInset(edge: .bottom) { timerBar }
            .tabItem {
                Label("Workout", systemImage: "dumbbell.fill")
            }
            .tag(AppTab.workout)

            NavigationStack {
                HistoryView()
            }
            .safeAreaInset(edge: .bottom) { timerBar }
            .tabItem {
                Label("History", systemImage: "calendar")
            }
            .tag(AppTab.history)

            NavigationStack {
                ExerciseLibraryView()
            }
            .safeAreaInset(edge: .bottom) { timerBar }
            .tabItem {
                Label("Exercises", systemImage: "figure.strengthtraining.traditional")
            }
            .tag(AppTab.exercises)

            NavigationStack {
                ProgressTabView()
            }
            .safeAreaInset(edge: .bottom) { timerBar }
            .tabItem {
                Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(AppTab.progress)
        }
        .environment(router)
        .onChange(of: scenePhase) { _, newPhase in
            handlePhaseChange(newPhase)
        }
    }

    /// The rest countdown follows the lifter across tabs.
    @ViewBuilder
    private var timerBar: some View {
        if restTimer.endDate != nil {
            RestTimerBar()
        }
    }

    private func handlePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .active {
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            WidgetDataStore.refresh(context: context)
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
