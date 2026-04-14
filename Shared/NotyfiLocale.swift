import Foundation

enum NotyfiLocale {
    static let languageStorageKey = "notyfi.language.preference"

    static func current(defaults: UserDefaults = .standard) -> Locale {
        guard let localeIdentifier = localeIdentifier(
            for: storedLanguageCode(defaults: defaults)
        ) else {
            return .autoupdatingCurrent
        }

        return Locale(identifier: localeIdentifier)
    }

    static func storedLanguageCode(defaults: UserDefaults = .standard) -> String {
        if let languageCode = defaults.string(forKey: languageStorageKey),
           !languageCode.isEmpty {
            return languageCode
        }

        let sharedDefaults = NotyfiSharedStorage.sharedDefaults()
        if let languageCode = sharedDefaults.string(forKey: languageStorageKey),
           !languageCode.isEmpty {
            return languageCode
        }

        return "system"
    }

    private static func localeIdentifier(for languageCode: String) -> String? {
        switch languageCode.lowercased() {
        case "", "system":
            return nil
        case "en":
            return "en_US"
        case "da":
            return "da_DK"
        case "de":
            return "de_DE"
        case "es":
            return "es_ES"
        case "fi":
            return "fi_FI"
        case "fr":
            return "fr_FR"
        case "it":
            return "it_IT"
        case "nb":
            return "nb_NO"
        case "nl":
            return "nl_NL"
        case "pl":
            return "pl_PL"
        case "pt":
            return "pt_PT"
        case "sv":
            return "sv_SE"
        default:
            return nil
        }
    }
}
