import Foundation

private enum NotyfiLocalization {
    static func bundle() -> Bundle {
        let selectedLanguage = NotyfiLanguage(
            rawValue: NotyfiLocale.storedLanguageCode()
        ) ?? .system

        guard let localeCode = selectedLanguage.localeCode,
              let path = Bundle.main.path(forResource: localeCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }

        return bundle
    }
}

extension String {
    var notyfiLocalized: String {
        NotyfiLocalization.bundle().localizedString(forKey: self, value: self, table: nil)
    }

    static func notyfiNotesCount(_ count: Int) -> String {
        let formatKey = count == 1 ? "Single note count format" : "Notes count format"
        return String(format: formatKey.notyfiLocalized, count)
    }
}
