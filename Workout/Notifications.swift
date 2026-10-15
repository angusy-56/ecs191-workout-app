import UIKit
import UserNotifications

/// Local notification for the end of a rest timer. Only one is ever pending:
/// scheduling always reuses the same identifier, so a new rest replaces the old one.
final class RestNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = RestNotifications()
    private let id = "rest-timer"
    private let center = UNUserNotificationCenter.current()

    func configure() { center.delegate = self }

    func schedule(at end: Date) {
        center.getNotificationSettings { [self] settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                // Asked the first time a rest timer starts, when the reason is obvious.
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { self.add(end) }
                }
            case .authorized, .provisional, .ephemeral:
                add(end)
            default:
                break
            }
        }
    }

    private func add(_ end: Date) {
        // Computed now (not when the rest started) so a late permission answer doesn't delay it.
        let seconds = end.timeIntervalSinceNow
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard seconds > 0.5 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Rest time is over!"
        content.body = "Time for your next set."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    // In the app, the rest bar shows the alert instead, so suppress the system banner.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        []
    }
}
