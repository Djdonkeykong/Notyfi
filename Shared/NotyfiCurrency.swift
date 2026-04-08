import Foundation

enum NotyfiCurrencyPreference: String, CaseIterable, Identifiable {
    case auto
    case nok
    case usd
    case eur
    case gbp
    case sek
    case dkk
    case chf
    case cad
    case aud
    case nzd
    case jpy
    case pln
    case sgd

    var id: String { rawValue }

    var currencyCode: String {
        switch self {
        case .auto:
            return NotyfiCurrency.deviceCode
        case .nok:
            return "NOK"
        case .usd:
            return "USD"
        case .eur:
            return "EUR"
        case .gbp:
            return "GBP"
        case .sek:
            return "SEK"
        case .dkk:
            return "DKK"
        case .chf:
            return "CHF"
        case .cad:
            return "CAD"
        case .aud:
            return "AUD"
        case .nzd:
            return "NZD"
        case .jpy:
            return "JPY"
        case .pln:
            return "PLN"
        case .sgd:
            return "SGD"
        }
    }

    var title: String {
        switch self {
        case .auto:
            return String(
                format: NSLocalizedString("Auto currency format", comment: ""),
                NotyfiCurrency.deviceCode
            )
        case .nok:
            return NotyfiCurrency.displayName(for: "NOK")
        case .usd:
            return NotyfiCurrency.displayName(for: "USD")
        case .eur:
            return NotyfiCurrency.displayName(for: "EUR")
        case .gbp:
            return NotyfiCurrency.displayName(for: "GBP")
        case .sek:
            return NotyfiCurrency.displayName(for: "SEK")
        case .dkk:
            return NotyfiCurrency.displayName(for: "DKK")
        case .chf:
            return NotyfiCurrency.displayName(for: "CHF")
        case .cad:
            return NotyfiCurrency.displayName(for: "CAD")
        case .aud:
            return NotyfiCurrency.displayName(for: "AUD")
        case .nzd:
            return NotyfiCurrency.displayName(for: "NZD")
        case .jpy:
            return NotyfiCurrency.displayName(for: "JPY")
        case .pln:
            return NotyfiCurrency.displayName(for: "PLN")
        case .sgd:
            return NotyfiCurrency.displayName(for: "SGD")
        }
    }
}

enum NotyfiCurrency {
    static let storageKey = "notyfi.preferences.currency"
    static let fallbackCode = "NOK"

    static var deviceCode: String {
        Locale.autoupdatingCurrent.currency?.identifier
            ?? Locale.current.currency?.identifier
            ?? fallbackCode
    }

    static func currentPreference(defaults: UserDefaults = .standard) -> NotyfiCurrencyPreference {
        guard let rawValue = defaults.string(forKey: storageKey),
              let preference = NotyfiCurrencyPreference(rawValue: rawValue) else {
            return .auto
        }

        return preference
    }

    static func currentCode(defaults: UserDefaults = .standard) -> String {
        currentPreference(defaults: defaults).currencyCode
    }

    static func displayName(for code: String) -> String {
        switch code.uppercased() {
        case "NOK":
            return NSLocalizedString("Norwegian Krone (NOK)", comment: "")
        case "USD":
            return NSLocalizedString("US Dollar (USD)", comment: "")
        case "EUR":
            return NSLocalizedString("Euro (EUR)", comment: "")
        case "GBP":
            return NSLocalizedString("British Pound (GBP)", comment: "")
        case "SEK":
            return NSLocalizedString("Swedish Krona (SEK)", comment: "")
        case "DKK":
            return NSLocalizedString("Danish Krone (DKK)", comment: "")
        case "CHF":
            return NSLocalizedString("Swiss Franc (CHF)", comment: "")
        case "CAD":
            return NSLocalizedString("Canadian Dollar (CAD)", comment: "")
        case "AUD":
            return NSLocalizedString("Australian Dollar (AUD)", comment: "")
        case "NZD":
            return NSLocalizedString("New Zealand Dollar (NZD)", comment: "")
        case "JPY":
            return NSLocalizedString("Japanese Yen (JPY)", comment: "")
        case "PLN":
            return NSLocalizedString("Polish Zloty (PLN)", comment: "")
        case "SGD":
            return NSLocalizedString("Singapore Dollar (SGD)", comment: "")
        default:
            return code.uppercased()
        }
    }
}
