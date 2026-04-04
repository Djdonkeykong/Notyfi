import Foundation

extension String {
    var notelyLocalized: String {
        NSLocalizedString(self, comment: "")
    }

    static func notelyNotesCount(_ count: Int) -> String {
        let formatKey = count == 1 ? "Single note count format" : "Notes count format"
        return String(format: formatKey.notelyLocalized, count)
    }
}
