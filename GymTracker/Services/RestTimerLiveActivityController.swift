import ActivityKit
import Foundation

/// App-side lifecycle for the rest-timer Live Activity. The widget UI counts
/// down on its own via Text(timerInterval:), so the only update ever sent is
/// an end-date change (+15s).
@MainActor
enum RestTimerLiveActivityController {
    static func start(startDate: Date, endDate: Date) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        await endAll()
        let state = RestTimerAttributes.ContentState(startDate: startDate, endDate: endDate)
        let content = ActivityContent(state: state, staleDate: endDate)
        _ = try? Activity<RestTimerAttributes>.request(
            attributes: RestTimerAttributes(),
            content: content,
            pushType: nil
        )
    }

    static func update(endDate: Date) async {
        for activity in Activity<RestTimerAttributes>.activities {
            let state = RestTimerAttributes.ContentState(
                startDate: activity.content.state.startDate,
                endDate: endDate
            )
            await activity.update(ActivityContent(state: state, staleDate: endDate))
        }
    }

    static func endAll() async {
        for activity in Activity<RestTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
