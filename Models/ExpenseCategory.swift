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
    case uncategorized

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food:
            return "Food".notelyLocalized
        case .groceries:
            return "Groceries".notelyLocalized
        case .transport:
            return "Transport".notelyLocalized
        case .housing:
            return "Housing".notelyLocalized
        case .travel:
            return "Travel".notelyLocalized
        case .shopping:
            return "Shopping".notelyLocalized
        case .bills:
            return "Bills".notelyLocalized
        case .health:
            return "Health".notelyLocalized
        case .social:
            return "Social".notelyLocalized
        case .uncategorized:
            return "Other".notelyLocalized
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
        case .uncategorized:
            return "circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .food:
            return Color(red: 0.93, green: 0.55, blue: 0.34)
        case .groceries:
            return Color(red: 0.35, green: 0.63, blue: 0.40)
        case .transport:
            return Color(red: 0.38, green: 0.58, blue: 0.86)
        case .housing:
            return Color(red: 0.64, green: 0.55, blue: 0.83)
        case .travel:
            return Color(red: 0.31, green: 0.67, blue: 0.74)
        case .shopping:
            return Color(red: 0.88, green: 0.56, blue: 0.72)
        case .bills:
            return Color(red: 0.70, green: 0.62, blue: 0.44)
        case .health:
            return Color(red: 0.87, green: 0.32, blue: 0.40)
        case .social:
            return Color(red: 0.87, green: 0.69, blue: 0.33)
        case .uncategorized:
            return Color.black.opacity(0.35)
        }
    }
}
