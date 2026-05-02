import SwiftUI

struct CustomCategoryDefinition: Codable, Identifiable, Hashable {
    let rawValue: String
    var title: String
    var symbol: String
    var tintR: Double
    var tintG: Double
    var tintB: Double

    var id: String { rawValue }

    var tint: Color { Color(red: tintR, green: tintG, blue: tintB) }

    var asExpenseCategory: ExpenseCategory { ExpenseCategory(rawValue: rawValue) }

    static func makeNew(
        title: String,
        symbol: String,
        tintR: Double,
        tintG: Double,
        tintB: Double
    ) -> CustomCategoryDefinition {
        let id = UUID()
        return CustomCategoryDefinition(
            rawValue: "custom_\(id.uuidString.lowercased())",
            title: title,
            symbol: symbol,
            tintR: tintR,
            tintG: tintG,
            tintB: tintB
        )
    }
}

// Shared registry so ExpenseCategory.title/symbol/tint can resolve custom values
// without needing a reference to the store.
final class CustomCategoryRegistry {
    static let shared = CustomCategoryRegistry()

    private var definitionsByRawValue: [String: CustomCategoryDefinition] = [:]

    func register(_ definitions: [CustomCategoryDefinition]) {
        definitionsByRawValue = Dictionary(
            uniqueKeysWithValues: definitions.map { ($0.rawValue, $0) }
        )
    }

    func definition(for rawValue: String) -> CustomCategoryDefinition? {
        definitionsByRawValue[rawValue]
    }

    var all: [CustomCategoryDefinition] {
        definitionsByRawValue.values.sorted { $0.title < $1.title }
    }
}
