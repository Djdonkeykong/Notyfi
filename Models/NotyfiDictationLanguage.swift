import Foundation

enum NotyfiDictationLanguage: String, CaseIterable, Identifiable {
    case appLanguage = "app_language"
    case autoDetect = "auto_detect"
    case english = "en-US"
    case danish = "da-DK"
    case german = "de-DE"
    case spanish = "es-ES"
    case finnish = "fi-FI"
    case french = "fr-FR"
    case italian = "it-IT"
    case norwegian = "nb-NO"
    case dutch = "nl-NL"
    case polish = "pl-PL"
    case portuguese = "pt-PT"
    case swedish = "sv-SE"

    static let storageKey = "notyfi.dictation.language"

    var id: String { rawValue }

    static var selectableLanguages: [NotyfiDictationLanguage] {
        allCases.filter { language in
            switch language {
            case .appLanguage, .autoDetect:
                return false
            default:
                return true
            }
        }
    }

    static func currentPreference(defaults: UserDefaults = .standard) -> NotyfiDictationLanguage {
        guard let rawValue = defaults.string(forKey: storageKey),
              let preference = NotyfiDictationLanguage(rawValue: rawValue) else {
            return .autoDetect
        }

        switch preference {
        case .appLanguage:
            return .autoDetect
        default:
            return preference
        }
    }

    var title: String {
        switch self {
        case .appLanguage:
            return "App language"
        case .autoDetect:
            return "Auto-detect"
        case .english:
            return "English"
        case .danish:
            return "Dansk"
        case .german:
            return "Deutsch"
        case .spanish:
            return "Espanol"
        case .finnish:
            return "Suomi"
        case .french:
            return "Francais"
        case .italian:
            return "Italiano"
        case .norwegian:
            return "Norsk"
        case .dutch:
            return "Nederlands"
        case .polish:
            return "Polski"
        case .portuguese:
            return "Portugues"
        case .swedish:
            return "Svenska"
        }
    }

    func preferredLocale(defaults: UserDefaults = .standard) -> Locale? {
        switch self {
        case .appLanguage:
            return appLanguageLocale(defaults: defaults)
        case .autoDetect:
            if let preferred = Locale.preferredLanguages.first {
                return Locale(identifier: preferred)
            }
            return .autoupdatingCurrent
        default:
            return Locale(identifier: rawValue)
        }
    }

    private func appLanguageLocale(defaults: UserDefaults) -> Locale {
        let selectedLanguage = NotyfiLanguage(
            rawValue: NotyfiLocale.storedLanguageCode(defaults: defaults)
        ) ?? .system

        let localeIdentifier: String
        switch selectedLanguage {
        case .system:
            localeIdentifier = Locale.preferredLanguages.first ?? Locale.autoupdatingCurrent.identifier
        case .english:
            localeIdentifier = Self.english.rawValue
        case .danish:
            localeIdentifier = Self.danish.rawValue
        case .german:
            localeIdentifier = Self.german.rawValue
        case .spanish:
            localeIdentifier = Self.spanish.rawValue
        case .finnish:
            localeIdentifier = Self.finnish.rawValue
        case .french:
            localeIdentifier = Self.french.rawValue
        case .italian:
            localeIdentifier = Self.italian.rawValue
        case .norwegian:
            localeIdentifier = Self.norwegian.rawValue
        case .dutch:
            localeIdentifier = Self.dutch.rawValue
        case .polish:
            localeIdentifier = Self.polish.rawValue
        case .portuguese:
            localeIdentifier = Self.portuguese.rawValue
        case .swedish:
            localeIdentifier = Self.swedish.rawValue
        }

        return Locale(identifier: localeIdentifier)
    }
}
