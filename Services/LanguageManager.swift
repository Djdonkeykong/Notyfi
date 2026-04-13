import Foundation

// Holds the active localization bundle so notyfiLocalized can use it.
// Starts as .main (picks up system language); updated whenever the user
// picks a specific language.
final class NotyfiBundle {
    static var current: Bundle = .main
}

@MainActor
final class LanguageManager: ObservableObject {
    static let storageKey = "notyfi.language.preference"

    @Published private(set) var current: NotyfiLanguage
    // Bumped on every language change so observers can force a re-render.
    @Published private(set) var refreshID: UUID = UUID()

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey)
        let lang = NotyfiLanguage(rawValue: saved ?? "") ?? .system
        current = lang
        Self.applyBundle(for: lang)
    }

    func set(_ language: NotyfiLanguage) {
        guard language != current else { return }
        current = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        Self.applyBundle(for: language)
        refreshID = UUID()
    }

    func applyStoredPreference() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey)
        let language = NotyfiLanguage(rawValue: saved ?? "") ?? .system
        guard language != current else { return }
        current = language
        Self.applyBundle(for: language)
        refreshID = UUID()
    }

    private static func applyBundle(for language: NotyfiLanguage) {
        guard let code = language.localeCode,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            NotyfiBundle.current = .main
            return
        }
        NotyfiBundle.current = bundle
    }
}
