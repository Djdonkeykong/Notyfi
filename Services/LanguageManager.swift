import Foundation

@MainActor
final class LanguageManager: ObservableObject {
    static let storageKey = NotyfiLocale.languageStorageKey

    @Published private(set) var current: NotyfiLanguage
    // Bumped on every language change so observers can force a re-render.
    @Published private(set) var refreshID: UUID = UUID()

    private let sharedDefaults = NotyfiSharedStorage.sharedDefaults()

    init() {
        let lang = NotyfiLanguage(
            rawValue: NotyfiLocale.storedLanguageCode()
        ) ?? .system
        current = lang
    }

    func set(_ language: NotyfiLanguage) {
        guard language != current else { return }
        current = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        sharedDefaults.set(language.rawValue, forKey: Self.storageKey)
        refreshID = UUID()
    }

    func applyStoredPreference() {
        let language = NotyfiLanguage(
            rawValue: NotyfiLocale.storedLanguageCode()
        ) ?? .system
        guard language != current else { return }
        current = language
        refreshID = UUID()
    }
}
