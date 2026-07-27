import ActivityKit
import Foundation

/// Shared between the app and the widget extension — the Live Activity's
/// identity and state. startDate stays fixed when +15s extends endDate, so
/// the progress bar remains truthful.
struct RestTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
    }
}
