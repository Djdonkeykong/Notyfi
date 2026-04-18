import SwiftUI

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case food
    case groceries
    case transport
    case housing
    case travel
    case shopping
    case bills
    case health
    case social
    case entertainment
    case uncategorized

    var id: String { rawValue }

    static var trackableCases: [ExpenseCategory] {
        allCases.filter { $0 != .uncategorized }
    }

    var title: String {
        switch self {
        case .food:
            return "Food".notyfiLocalized
        case .groceries:
            return "Groceries".notyfiLocalized
        case .transport:
            return "Transport".notyfiLocalized
        case .housing:
            return "Housing".notyfiLocalized
        case .travel:
            return "Travel".notyfiLocalized
        case .shopping:
            return "Shopping".notyfiLocalized
        case .bills:
            return "Bills".notyfiLocalized
        case .health:
            return "Health".notyfiLocalized
        case .social:
            return "Social".notyfiLocalized
        case .entertainment:
            return "Entertainment".notyfiLocalized
        case .uncategorized:
            return "Other".notyfiLocalized
        }
    }

    var symbol: String {
        switch self {
        case .food:
            return "fork.knife"
        case .groceries:
            return "basket"
        case .transport:
            return "car.fill"
        case .housing:
            return "house.fill"
        case .travel:
            return "airplane"
        case .shopping:
            return "bag.fill"
        case .bills:
            return "doc.text.fill"
        case .health:
            return "cross.case.fill"
        case .social:
            return "person.2.fill"
        case .entertainment:
            return "tv.fill"
        case .uncategorized:
            return "circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .food:
            return Color(red: 1.00, green: 0.44, blue: 0.16)   // vivid orange
        case .groceries:
            return Color(red: 0.16, green: 0.76, blue: 0.38)   // vivid emerald
        case .transport:
            return Color(red: 0.20, green: 0.48, blue: 0.98)   // bold blue
        case .housing:
            return Color(red: 0.60, green: 0.36, blue: 0.96)   // vivid violet
        case .travel:
            return Color(red: 0.06, green: 0.74, blue: 0.84)   // vivid cyan
        case .shopping:
            return Color(red: 0.98, green: 0.24, blue: 0.58)   // hot pink
        case .bills:
            return Color(red: 0.96, green: 0.68, blue: 0.08)   // vivid amber
        case .health:
            return Color(red: 0.96, green: 0.18, blue: 0.26)   // vivid red
        case .social:
            return Color(red: 0.98, green: 0.55, blue: 0.08)   // vivid saffron
        case .entertainment:
            return Color(red: 0.40, green: 0.22, blue: 0.96)   // vivid indigo
        case .uncategorized:
            return NotyfiTheme.tertiaryText
        }
    }
}
