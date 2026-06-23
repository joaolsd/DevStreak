import Foundation
import UserNotifications

@MainActor
final class NotificationManager {

    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    private let reminderID = "devstreak.daily.reminder"

    private init() {}

    // MARK: – Permission

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: – Schedule

    /// Schedule (or reschedule) a daily local notification at `hour`:`minute`.
    func scheduleDailyReminder(hour: Int, minute: Int) async {
        // Remove any existing reminder first
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])

        let granted = await requestPermission()
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Dev session"
        content.body  = "30 minutes of code keeps the streak alive 🔥"
        content.sound = .default

        var comps = DateComponents()
        comps.hour   = hour
        comps.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)

        try? await center.add(request)

        // Persist chosen time
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
        defaults.set(hour,   forKey: AppConstants.reminderHourKey)
        defaults.set(minute, forKey: AppConstants.reminderMinuteKey)
    }

    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
    }

    /// Returns the currently scheduled reminder time, if any.
    func scheduledReminderTime() async -> (hour: Int, minute: Int)? {
        let pending = await center.pendingNotificationRequests()
        guard let req = pending.first(where: { $0.identifier == reminderID }),
              let trigger = req.trigger as? UNCalendarNotificationTrigger,
              let hour = trigger.dateComponents.hour,
              let minute = trigger.dateComponents.minute
        else { return nil }
        return (hour, minute)
    }
}
