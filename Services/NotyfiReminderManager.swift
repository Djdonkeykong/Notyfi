import Foundation
import UserNotifications

@MainActor
final class NotyfiReminderManager {
    static let shared = NotyfiReminderManager()

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let reminderIdentifier = "notyfi.daily-reminder"

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = NotyfiSharedStorage.sharedDefaults()
    ) {
        self.center = center
        self.defaults = defaults
    }

    func loadSettings() -> NotyfiReminderSettings {
        let enabled = defaults.object(forKey: NotyfiSharedStorage.reminderEnabledKey) as? Bool
            ?? NotyfiReminderSettings.default.isEnabled
        let hour = defaults.object(forKey: NotyfiSharedStorage.reminderHourKey) as? Int
            ?? NotyfiReminderSettings.default.hour
        let minute = defaults.object(forKey: NotyfiSharedStorage.reminderMinuteKey) as? Int
            ?? NotyfiReminderSettings.default.minute

        return NotyfiReminderSettings(
            isEnabled: enabled,
            hour: hour,
            minute: minute
        )
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func enableReminder(at dateComponents: DateComponents) async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else {
                persist(
                    NotyfiReminderSettings(
                        isEnabled: false,
                        hour: dateComponents.hour ?? NotyfiReminderSettings.default.hour,
                        minute: dateComponents.minute ?? NotyfiReminderSettings.default.minute
                    )
                )
                return false
            }

            let reminderSettings = NotyfiReminderSettings(
                isEnabled: true,
                hour: dateComponents.hour ?? NotyfiReminderSettings.default.hour,
                minute: dateComponents.minute ?? NotyfiReminderSettings.default.minute
            )
            persist(reminderSettings)
            await scheduleReminder(using: reminderSettings)
            return true
        } catch {
            persist(
                NotyfiReminderSettings(
                    isEnabled: false,
                    hour: dateComponents.hour ?? NotyfiReminderSettings.default.hour,
                    minute: dateComponents.minute ?? NotyfiReminderSettings.default.minute
                )
            )
            return false
        }
    }

    func disableReminder() async {
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
        let current = loadSettings()
        persist(
            NotyfiReminderSettings(
                isEnabled: false,
                hour: current.hour,
                minute: current.minute
            )
        )
    }

    func updateReminderTime(_ dateComponents: DateComponents) async {
        let current = loadSettings()
        let next = NotyfiReminderSettings(
            isEnabled: current.isEnabled,
            hour: dateComponents.hour ?? current.hour,
            minute: dateComponents.minute ?? current.minute
        )
        persist(next)

        guard current.isEnabled else {
            return
        }

        await scheduleReminder(using: next)
    }

    private func scheduleReminder(using settings: NotyfiReminderSettings) async {
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Log today's money notes".notyfiLocalized
        content.body = "Open Notyfi and capture today's spending while it is still fresh.".notyfiLocalized
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: settings.dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: reminderIdentifier,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    private func persist(_ settings: NotyfiReminderSettings) {
        defaults.set(settings.isEnabled, forKey: NotyfiSharedStorage.reminderEnabledKey)
        defaults.set(settings.hour, forKey: NotyfiSharedStorage.reminderHourKey)
        defaults.set(settings.minute, forKey: NotyfiSharedStorage.reminderMinuteKey)
    }
}
