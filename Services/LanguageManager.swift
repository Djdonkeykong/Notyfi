import Foundation

// Holds the active localization bundle so notyfiLocalized can use it.
// Starts as .main (picks up system language); updated whenever the user
// picks a specific language.
final class NotyfiBundle {
    static var current: Bundle = .main
    static var usesStrictLocalization = false

    private static let englishFallbackBundle: Bundle = {
        guard let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }

        return bundle
    }()

    private static var stringsCache: [String: [String: String]] = [:]

    static func localizedString(forKey key: String, table: String? = nil) -> String {
        guard usesStrictLocalization else {
            return current.localizedString(forKey: key, value: key, table: table)
        }

        if let localizedValue = exactLocalizedString(forKey: key, in: current, table: table) {
            return localizedValue
        }

        if let fallbackValue = exactLocalizedString(forKey: key, in: englishFallbackBundle, table: table) {
            return fallbackValue
        }

        return key
    }

    private static func exactLocalizedString(
        forKey key: String,
        in bundle: Bundle,
        table: String?
    ) -> String? {
        let tableName = table ?? "Localizable"

        guard let stringsPath = bundle.path(forResource: tableName, ofType: "strings") else {
            return nil
        }

        let cacheKey = "\(stringsPath)|\(tableName)"
        let tableValues: [String: String]
        if let cached = stringsCache[cacheKey] {
            tableValues = cached
        } else {
            let parsedValues = NSDictionary(contentsOfFile: stringsPath) as? [String: String] ?? [:]
            stringsCache[cacheKey] = parsedValues
            tableValues = parsedValues
        }

        return tableValues[key]
    }
}

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
        Self.applyBundle(for: lang)
    }

    func set(_ language: NotyfiLanguage) {
        guard language != current else { return }
        current = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        sharedDefaults.set(language.rawValue, forKey: Self.storageKey)
        Self.applyBundle(for: language)
        refreshID = UUID()
    }

    func applyStoredPreference() {
        let language = NotyfiLanguage(
            rawValue: NotyfiLocale.storedLanguageCode()
        ) ?? .system
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
            NotyfiBundle.usesStrictLocalization = false
            return
        }
        NotyfiBundle.current = bundle
        NotyfiBundle.usesStrictLocalization = true
    }
}
