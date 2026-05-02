import SwiftUI

struct ExpenseCategory: Hashable, Identifiable {
    let rawValue: String

    var id: String { rawValue }

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    // MARK: - Built-in cases

    static let food          = ExpenseCategory(rawValue: "food")
    static let groceries     = ExpenseCategory(rawValue: "groceries")
    static let transport     = ExpenseCategory(rawValue: "transport")
    static let housing       = ExpenseCategory(rawValue: "housing")
    static let travel        = ExpenseCategory(rawValue: "travel")
    static let shopping      = ExpenseCategory(rawValue: "shopping")
    static let bills         = ExpenseCategory(rawValue: "bills")
    static let health        = ExpenseCategory(rawValue: "health")
    static let social        = ExpenseCategory(rawValue: "social")
    static let entertainment = ExpenseCategory(rawValue: "entertainment")
    static let uncategorized = ExpenseCategory(rawValue: "uncategorized")

    static let builtIn: [ExpenseCategory] = [
        .food, .groceries, .transport, .housing, .travel,
        .shopping, .bills, .health, .social, .entertainment, .uncategorized,
    ]

    private static let builtInRawValues: Set<String> = Set(builtIn.map(\.rawValue))

    // allCases covers only built-ins; use store.allCategories for full list
    static var allCases: [ExpenseCategory] { builtIn }

    static var trackableCases: [ExpenseCategory] {
        builtIn.filter { $0.rawValue != "uncategorized" }
    }

    // MARK: - Computed properties

    var isBuiltIn: Bool { Self.builtInRawValues.contains(rawValue) }
    var isCustom: Bool { !isBuiltIn }

    var title: String {
        switch rawValue {
        case "food":          return "Food".notyfiLocalized
        case "groceries":     return "Groceries".notyfiLocalized
        case "transport":     return "Transport".notyfiLocalized
        case "housing":       return "Housing".notyfiLocalized
        case "travel":        return "Travel".notyfiLocalized
        case "shopping":      return "Shopping".notyfiLocalized
        case "bills":         return "Bills".notyfiLocalized
        case "health":        return "Health".notyfiLocalized
        case "social":        return "Social".notyfiLocalized
        case "entertainment": return "Entertainment".notyfiLocalized
        case "uncategorized": return "Other".notyfiLocalized
        default:
            return CustomCategoryRegistry.shared.definition(for: rawValue)?.title ?? rawValue
        }
    }

    var symbol: String {
        switch rawValue {
        case "food":          return "fork.knife"
        case "groceries":     return "basket"
        case "transport":     return "car.fill"
        case "housing":       return "house.fill"
        case "travel":        return "airplane"
        case "shopping":      return "bag.fill"
        case "bills":         return "doc.text.fill"
        case "health":        return "cross.case.fill"
        case "social":        return "person.2.fill"
        case "entertainment": return "tv.fill"
        case "uncategorized": return "circle.fill"
        default:
            return CustomCategoryRegistry.shared.definition(for: rawValue)?.symbol ?? "tag.fill"
        }
    }

    var tint: Color {
        switch rawValue {
        case "food":          return Color(red: 1.00, green: 0.44, blue: 0.16)
        case "groceries":     return Color(red: 0.16, green: 0.76, blue: 0.38)
        case "transport":     return Color(red: 0.20, green: 0.48, blue: 0.98)
        case "housing":       return Color(red: 0.60, green: 0.36, blue: 0.96)
        case "travel":        return Color(red: 0.06, green: 0.74, blue: 0.84)
        case "shopping":      return Color(red: 0.98, green: 0.24, blue: 0.58)
        case "bills":         return Color(red: 0.96, green: 0.68, blue: 0.08)
        case "health":        return Color(red: 0.96, green: 0.18, blue: 0.26)
        case "social":        return Color(red: 0.98, green: 0.55, blue: 0.08)
        case "entertainment": return Color(red: 0.40, green: 0.22, blue: 0.96)
        case "uncategorized": return NotyfiTheme.tertiaryText
        default:
            if let def = CustomCategoryRegistry.shared.definition(for: rawValue) {
                return Color(red: def.tintR, green: def.tintG, blue: def.tintB)
            }
            return NotyfiTheme.tertiaryText
        }
    }
}

// MARK: - Codable

extension ExpenseCategory: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
