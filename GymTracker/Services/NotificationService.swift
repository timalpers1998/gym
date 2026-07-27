import Foundation
import UserNotifications

enum NotificationService {
    static let restDoneIdentifier = "rest-timer-done"

    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    static func scheduleRestDoneNotification(at date: Date) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [restDoneIdentifier])

        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Time for your next set."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        let request = UNNotificationRequest(identifier: restDoneIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelRestDoneNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [restDoneIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [restDoneIdentifier])
    }
}
