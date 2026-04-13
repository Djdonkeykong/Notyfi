import Foundation

enum NotyfiLocale {
    static func current(defaults: UserDefaults = .standard) -> Locale {
        let selectedLanguage = NotyfiLanguage(
            rawValue: defaults.string(forKey: LanguageManager.storageKey) ?? ""
        ) ?? .system

        guard let localeIdentifier = selectedLanguage.localeIdentifier else {
            return .autoupdatingCurrent
        }

        return Locale(identifier: localeIdentifier)
    }
}
