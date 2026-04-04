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

enum TransactionKind: String, Codable, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expense:
            return "Expense"
        case .income:
            return "Income"
        }
    }

    var signedMultiplier: Double {
        switch self {
        case .expense:
            return -1
        case .income:
            return 1
        }
    }
}

struct ExpenseEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var rawText: String
    var title: String
    var amount: Double
    var currencyCode: String
    var transactionKind: TransactionKind
    var category: ExpenseCategory
    var merchant: String?
    var date: Date
    var note: String
    var confidence: ParsingConfidence
    var isAmountEstimated: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        rawText: String,
        title: String,
        amount: Double,
        currencyCode: String = "NOK",
        transactionKind: TransactionKind = .expense,
        category: ExpenseCategory,
        merchant: String? = nil,
        date: Date,
        note: String = "",
        confidence: ParsingConfidence,
        isAmountEstimated: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.rawText = rawText
        self.title = title
        self.amount = amount
        self.currencyCode = currencyCode
        self.transactionKind = transactionKind
        self.category = category
        self.merchant = merchant
        self.date = date
        self.note = note
        self.confidence = confidence
        self.isAmountEstimated = isAmountEstimated
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case rawText
        case title
        case amount
        case currencyCode
        case transactionKind
        case category
        case merchant
        case date
        case note
        case confidence
        case isAmountEstimated
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        rawText = try container.decode(String.self, forKey: .rawText)
        title = try container.decode(String.self, forKey: .title)
        amount = try container.decode(Double.self, forKey: .amount)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        transactionKind = try container.decodeIfPresent(TransactionKind.self, forKey: .transactionKind) ?? .expense
        category = try container.decode(ExpenseCategory.self, forKey: .category)
        merchant = try container.decodeIfPresent(String.self, forKey: .merchant)
        date = try container.decode(Date.self, forKey: .date)
        note = try container.decode(String.self, forKey: .note)
        confidence = try container.decode(ParsingConfidence.self, forKey: .confidence)
        isAmountEstimated = try container.decodeIfPresent(Bool.self, forKey: .isAmountEstimated) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(rawText, forKey: .rawText)
        try container.encode(title, forKey: .title)
        try container.encode(amount, forKey: .amount)
        try container.encode(currencyCode, forKey: .currencyCode)
        try container.encode(transactionKind, forKey: .transactionKind)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(merchant, forKey: .merchant)
        try container.encode(date, forKey: .date)
        try container.encode(note, forKey: .note)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(isAmountEstimated, forKey: .isAmountEstimated)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
