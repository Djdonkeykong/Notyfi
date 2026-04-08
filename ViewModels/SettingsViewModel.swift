import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var appearanceMode: NotyfiAppearanceMode
    @Published var currencyPreference: NotyfiCurrencyPreference
    @Published var remindersEnabled = false
    @Published var reminderTime: Date
    @Published private(set) var remindersPermissionDenied = false

    private let store: ExpenseJournalStore
    private let reminderManager: NotyfiReminderManager
    private let calendar: Calendar
    private let defaults: UserDefaults

    init(
        store: ExpenseJournalStore,
        reminderManager: NotyfiReminderManager? = nil,
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.reminderManager = reminderManager ?? .shared
        self.calendar = calendar
        self.defaults = defaults
        self.appearanceMode = NotyfiAppearanceMode(
            rawValue: defaults.string(forKey: NotyfiAppearanceMode.storageKey) ?? ""
        ) ?? .system
        self.currencyPreference = NotyfiCurrency.currentPreference(defaults: defaults)

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

    func setAppearanceMode(_ mode: NotyfiAppearanceMode) {
        appearanceMode = mode
        defaults.set(mode.rawValue, forKey: NotyfiAppearanceMode.storageKey)
    }

    func setCurrencyPreference(_ preference: NotyfiCurrencyPreference) {
        currencyPreference = preference
        defaults.set(preference.rawValue, forKey: NotyfiCurrency.storageKey)
    }

    private var reminderDateComponents: DateComponents {
        calendar.dateComponents([.hour, .minute], from: reminderTime)
    }

    private func refreshReminderAuthorization() async {
        remindersPermissionDenied = await reminderManager.authorizationStatus() == .denied
    }
}
