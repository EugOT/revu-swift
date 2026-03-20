import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("Notification permission error: \(error)")
            }
            if !granted {
                print("Notification permission not granted")
            }
        }
    }

    func scheduleDailyReminder(for settings: UserSettings) {
        guard settings.notificationsEnabled else {
            cancelReminders()
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Reviews waiting"
        content.body = "You have flashcards ready for review."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = settings.notificationHour
        dateComponents.minute = settings.notificationMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "revu.dailyReminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    func cancelReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["revu.dailyReminder"])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
