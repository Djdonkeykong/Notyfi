import Foundation

enum ParsingConfidence: String, Codable, CaseIterable, Identifiable {
    case certain
    case review
    case uncertain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .certain:
            return "Clear"
        case .review:
            return "Review"
        case .uncertain:
            return "Low"
        }
    }

    var needsReview: Bool {
        self != .certain
    }
}

struct ExpenseEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var rawText: String
    var title: String
    var amount: Double
    var currencyCode: String
    var category: ExpenseCategory
    var merchant: String?
    var date: Date
    var note: String
    var confidence: ParsingConfidence
    var createdAt: Date

    init(
        id: UUID = UUID(),
        rawText: String,
        title: String,
        amount: Double,
        currencyCode: String = "NOK",
        category: ExpenseCategory,
        merchant: String? = nil,
        date: Date,
        note: String = "",
        confidence: ParsingConfidence,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.rawText = rawText
        self.title = title
        self.amount = amount
        self.currencyCode = currencyCode
        self.category = category
        self.merchant = merchant
        self.date = date
        self.note = note
        self.confidence = confidence
        self.createdAt = createdAt
    }
}

