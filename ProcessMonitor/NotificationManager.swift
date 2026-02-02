import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func notifyMissingConfig() {
        sendNotification(
            title: "ProcessMonitor",
            body: "Config file not found at \(MonitorConfig.configPath.path). Create it to start monitoring."
        )
    }

    func notifyUnhealthy(processName: String, reason: String) {
        sendNotification(
            title: "ProcessMonitor: \(processName) unhealthy",
            body: reason
        )
    }
}
