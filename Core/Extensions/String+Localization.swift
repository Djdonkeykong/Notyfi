import Foundation

extension String {
    var notyfiLocalized: String {
        NSLocalizedString(self, comment: "")
    }

    static func notyfiNotesCount(_ count: Int) -> String {
        let formatKey = count == 1 ? "Single note count format" : "Notes count format"
        return String(format: formatKey.notyfiLocalized, count)
    }
}
