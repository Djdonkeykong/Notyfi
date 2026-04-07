import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    enum AppearanceMode: String, Identifiable {
        case system

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system:
                return "System".notyfiLocalized
            }
        }
    }

    @Published var appearanceMode: AppearanceMode = .system
    @Published var currencyCode = "NOK"
    @Published var remindersEnabled = false
    @Published var reminderTime: Date
    @Published private(set) var remindersPermissionDenied = false

    private let store: ExpenseJournalStore
    private let reminderManager: NotyfiReminderManager
    private let calendar: Calendar

    init(
        store: ExpenseJournalStore,
        reminderManager: NotyfiReminderManager? = nil,
        calendar: Calendar = .current
    ) {
        self.store = store
        self.reminderManager = reminderManager ?? .shared
        self.calendar = calendar

        let reminderSettings = self.reminderManager.loadSettings()
        self.remindersEnabled = reminderSettings.isEnabled
        self.reminderTime = calendar.date(
            from: DateComponents(
                hour: reminderSettings.hour,
                minute: reminderSettings.minute
            )
        ) ?? .now

        Task {
            await refreshReminderAuthorization()
        }
    }

    var currencyDisplayName: String {
        switch currencyCode.uppercased() {
        case "NOK":
            return "Norwegian Krone (NOK)".notyfiLocalized
        case "USD":
            return "US Dollar (USD)".notyfiLocalized
        case "EUR":
            return "Euro (EUR)".notyfiLocalized
        default:
            return currencyCode
        }
    }

    var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (version?, build?) where version != build:
            return "\(version) (\(build))"
        case let (version?, _):
            return version
        case let (_, build?):
            return build
        default:
            return "1.0"
        }
    }

    var reminderSubtitle: String {
        if remindersPermissionDenied {
            return "Allow notifications in iPhone Settings to turn this on.".notyfiLocalized
        }

        return "A gentle nudge to log your day before you forget.".notyfiLocalized
    }

    func setRemindersEnabled(_ isEnabled: Bool) async {
        if isEnabled {
            let granted = await reminderManager.enableReminder(
                at: reminderDateComponents
            )
            remindersEnabled = granted
            await refreshReminderAuthorization()
        } else {
            await reminderManager.disableReminder()
            remindersEnabled = false
            await refreshReminderAuthorization()
        }
    }

    func setReminderTime(_ date: Date) async {
        reminderTime = date
        await reminderManager.updateReminderTime(reminderDateComponents)
    }

    func clearLog() {
        store.clearAllEntries()
    }

    private var reminderDateComponents: DateComponents {
        calendar.dateComponents([.hour, .minute], from: reminderTime)
    }

    private func refreshReminderAuthorization() async {
        remindersPermissionDenied = await reminderManager.authorizationStatus() == .denied
    }
}
