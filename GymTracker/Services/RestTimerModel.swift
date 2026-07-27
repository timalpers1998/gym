import Foundation
import Observation

/// App-wide rest timer. The end date is the single source of truth; remaining
/// time is always computed against the current date, so the countdown stays
/// correct across backgrounding without a running Timer.
@MainActor
@Observable
final class RestTimerModel {
    private(set) var endDate: Date? = nil
    private(set) var totalDuration: TimeInterval = 0

    private let settings: AppSettings
    private var hasRequestedAuthorization = false

    private enum Keys {
        static let endDate = "restTimer.endDate"
        static let totalDuration = "restTimer.totalDuration"
    }

    init(settings: AppSettings) {
        self.settings = settings

        // Restore a timer that was running when the app was killed; the
        // scheduled notification is still pending, so only UI state is needed.
        let defaults = UserDefaults.standard
        if let stored = defaults.object(forKey: Keys.endDate) as? Date, stored > Date.now {
            endDate = stored
            totalDuration = defaults.double(forKey: Keys.totalDuration)
        } else {
            defaults.removeObject(forKey: Keys.endDate)
            defaults.removeObject(forKey: Keys.totalDuration)
            // A Live Activity from a previous run may be lingering in its
            // stale "Done" state; dismiss it. ActivityKit restores existing
            // activities asynchronously after launch, so wait briefly before
            // enumerating them.
            Task {
                try? await Task.sleep(for: .seconds(2))
                await RestTimerLiveActivityController.endAll()
            }
        }
    }

    private func persist() {
        let defaults = UserDefaults.standard
        if let endDate {
            defaults.set(endDate, forKey: Keys.endDate)
            defaults.set(totalDuration, forKey: Keys.totalDuration)
        } else {
            defaults.removeObject(forKey: Keys.endDate)
            defaults.removeObject(forKey: Keys.totalDuration)
        }
    }

    var isActive: Bool {
        guard let endDate else { return false }
        return endDate > Date.now
    }

    func remainingSeconds(at date: Date) -> Int {
        guard let endDate else { return 0 }
        return max(0, Int(endDate.timeIntervalSince(date).rounded(.up)))
    }

    func progress(at date: Date) -> Double {
        guard totalDuration > 0, let endDate else { return 0 }
        let remaining = max(0, endDate.timeIntervalSince(date))
        return min(1, max(0, 1 - remaining / totalDuration))
    }

    func start(duration: Int? = nil) {
        let seconds = TimeInterval(duration ?? settings.restDurationSeconds)
        totalDuration = seconds
        let startDate = Date.now
        let end = startDate.addingTimeInterval(seconds)
        endDate = end
        persist()
        Task {
            if !hasRequestedAuthorization {
                hasRequestedAuthorization = true
                await NotificationService.requestAuthorizationIfNeeded()
            }
            await NotificationService.scheduleRestDoneNotification(at: end)
            await RestTimerLiveActivityController.start(startDate: startDate, endDate: end)
        }
    }

    func add(seconds: TimeInterval) {
        guard let current = endDate, current > Date.now else { return }
        totalDuration += seconds
        let end = current.addingTimeInterval(seconds)
        endDate = end
        persist()
        Task {
            await NotificationService.scheduleRestDoneNotification(at: end)
            await RestTimerLiveActivityController.update(endDate: end)
        }
    }

    func skip() {
        endDate = nil
        totalDuration = 0
        persist()
        NotificationService.cancelRestDoneNotification()
        Task {
            await RestTimerLiveActivityController.endAll()
        }
    }

    /// Called when the countdown reaches zero naturally; the notification has
    /// already fired, so only local state needs clearing.
    func finish() {
        endDate = nil
        totalDuration = 0
        persist()
        Task {
            await RestTimerLiveActivityController.endAll()
        }
    }
}
