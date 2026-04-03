import Foundation

@MainActor
final class EntryDetailViewModel: ObservableObject {
    @Published var rawText: String
    @Published var title: String
    @Published var amountText: String
    @Published var category: ExpenseCategory
    @Published var date: Date
    @Published var merchant: String
    @Published var note: String
    @Published var needsReview: Bool
    @Published private(set) var isAmountEstimated: Bool

    let currencyCode: String

    private let store: ExpenseJournalStore
    private let entryID: UUID
    private let createdAt: Date

    init(entry: ExpenseEntry, store: ExpenseJournalStore) {
        self.rawText = entry.rawText
        self.title = entry.title
        self.amountText = entry.amount == 0 ? "" : String(format: "%.0f", entry.amount)
        self.category = entry.category
        self.date = entry.date
        self.merchant = entry.merchant ?? ""
        self.note = entry.note
        self.needsReview = entry.confidence.needsReview
        self.isAmountEstimated = entry.isAmountEstimated
        self.currencyCode = entry.currencyCode
        self.store = store
        self.entryID = entry.id
        self.createdAt = entry.createdAt
    }

    func save() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let updated = ExpenseEntry(
            id: entryID,
            rawText: rawText.trimmingCharacters(in: .whitespacesAndNewlines),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            currencyCode: currencyCode,
            category: category,
            merchant: merchant.isEmpty ? nil : merchant,
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: needsReview ? .review : .certain,
            isAmountEstimated: needsReview && isAmountEstimated,
            createdAt: createdAt
        )

        store.updateEntry(updated)
    }
}
