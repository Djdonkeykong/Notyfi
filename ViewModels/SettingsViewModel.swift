import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var appearanceMode: NotyfiAppearanceMode
    @Published var currencyPreference: NotyfiCurrencyPreference
    @Published var dictationLanguage: NotyfiDictationLanguage
    @Published var remindersEnabled = false
    @Published var reminderFrequency: ReminderFrequency
    @Published private(set) var remindersPermissionDenied = false

    private let store: ExpenseJournalStore
    private let reminderManager: NotyfiReminderManager
    private let defaults: UserDefaults

    init(
        store: ExpenseJournalStore,
        reminderManager: NotyfiReminderManager? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.reminderManager = reminderManager ?? .shared
        self.defaults = defaults
        self.appearanceMode = NotyfiAppearanceMode(
            rawValue: defaults.string(forKey: NotyfiAppearanceMode.storageKey) ?? ""
        ) ?? .system
        self.currencyPreference = NotyfiCurrency.currentPreference(defaults: defaults)
        self.dictationLanguage = NotyfiDictationLanguage.currentPreference(defaults: defaults)

        let reminderSettings = self.reminderManager.loadSettings()
        self.remindersEnabled = reminderSettings.isEnabled
        self.reminderFrequency = self.reminderManager.loadFrequency()

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

    var journalStore: ExpenseJournalStore {
        store
    }

    func setRemindersEnabled(_ isEnabled: Bool) async {
        if isEnabled {
            let granted = await reminderManager.enableReminders(frequency: reminderFrequency)
            remindersEnabled = granted
            await refreshReminderAuthorization()
        } else {
            await reminderManager.disableReminder()
            remindersEnabled = false
            await refreshReminderAuthorization()
        }
    }

    func setReminderFrequency(_ frequency: ReminderFrequency) async {
        reminderFrequency = frequency
        guard remindersEnabled else { return }
        await reminderManager.updateFrequency(frequency)
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

    func setDictationLanguage(_ language: NotyfiDictationLanguage) {
        dictationLanguage = language
        defaults.set(language.rawValue, forKey: NotyfiDictationLanguage.storageKey)
    }

    private func refreshReminderAuthorization() async {
        remindersPermissionDenied = await reminderManager.authorizationStatus() == .denied
    }
}
