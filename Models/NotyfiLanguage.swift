import Foundation

enum NotyfiLanguage: String, CaseIterable, Identifiable {
    case system    = "system"
    case english   = "en"
    case danish    = "da"
    case german    = "de"
    case spanish   = "es"
    case finnish   = "fi"
    case french    = "fr"
    case italian   = "it"
    case norwegian = "nb"
    case dutch     = "nl"
    case polish    = "pl"
    case portuguese = "pt"
    case swedish   = "sv"

    var id: String { rawValue }

    var localeCode: String? {
        self == .system ? nil : rawValue
    }

    var localeIdentifier: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en_US"
        case .danish:
            return "da_DK"
        case .german:
            return "de_DE"
        case .spanish:
            return "es_ES"
        case .finnish:
            return "fi_FI"
        case .french:
            return "fr_FR"
        case .italian:
            return "it_IT"
        case .norwegian:
            return "nb_NO"
        case .dutch:
            return "nl_NL"
        case .polish:
            return "pl_PL"
        case .portuguese:
            return "pt_PT"
        case .swedish:
            return "sv_SE"
        }
    }

    var flag: String {
        switch self {
        case .system:      return ""
        case .english:     return "🇺🇸"
        case .danish:      return "🇩🇰"
        case .german:      return "🇩🇪"
        case .spanish:     return "🇪🇸"
        case .finnish:     return "🇫🇮"
        case .french:      return "🇫🇷"
        case .italian:     return "🇮🇹"
        case .norwegian:   return "🇳🇴"
        case .dutch:       return "🇳🇱"
        case .polish:      return "🇵🇱"
        case .portuguese:  return "🇧🇷"
        case .swedish:     return "🇸🇪"
        }
    }

    var displayName: String {
        switch self {
        case .system:      return "Follow System"
        case .english:     return "English"
        case .danish:      return "Dansk"
        case .german:      return "Deutsch"
        case .spanish:     return "Español"
        case .finnish:     return "Suomi"
        case .french:      return "Français"
        case .italian:     return "Italiano"
        case .norwegian:   return "Norsk"
        case .dutch:       return "Nederlands"
        case .polish:      return "Polski"
        case .portuguese:  return "Português"
        case .swedish:     return "Svenska"
        }
    }

    var promptLanguageName: String {
        switch self {
        case .system:      return "System language"
        case .english:     return "English"
        case .danish:      return "Danish"
        case .german:      return "German"
        case .spanish:     return "Spanish"
        case .finnish:     return "Finnish"
        case .french:      return "French"
        case .italian:     return "Italian"
        case .norwegian:   return "Norwegian"
        case .dutch:       return "Dutch"
        case .polish:      return "Polish"
        case .portuguese:  return "Portuguese"
        case .swedish:     return "Swedish"
        }
    }

    // Short label shown in the pill (e.g. "EN", "DE")
    var shortLabel: String {
        switch self {
        case .system:      return "Auto"
        default:           return rawValue.uppercased()
        }
    }
}
