import Foundation

@MainActor
final class EntryDetailViewModel: ObservableObject {
    @Published var rawText: String
    @Published var title: String
    @Published var amountText: String
    @Published var transactionKind: TransactionKind
    @Published var category: ExpenseCategory
    @Published var date: Date
    @Published var merchant: String
    @Published var note: String
    @Published var needsReview: Bool
    @Published private(set) var isAmountEstimated: Bool

    let currencyCode: String
    let recurringTransactionID: UUID?
    let recurrenceInstanceKey: String?

    private let store: ExpenseJournalStore
    private let entryID: UUID
    private let createdAt: Date

    init(entry: ExpenseEntry, store: ExpenseJournalStore) {
        self.rawText = entry.rawText
        self.title = entry.title
        self.amountText = entry.amount == 0 ? "" : String(format: "%.0f", entry.amount)
        self.transactionKind = entry.transactionKind
        self.category = entry.category
        self.date = entry.date
        self.merchant = entry.merchant ?? ""
        self.note = entry.note
        self.needsReview = entry.confidence.needsReview
        self.isAmountEstimated = entry.isAmountEstimated
        self.currencyCode = entry.currencyCode
        self.recurringTransactionID = entry.recurringTransactionID
        self.recurrenceInstanceKey = entry.recurrenceInstanceKey
        self.store = store
        self.entryID = entry.id
        self.createdAt = entry.createdAt
    }

    func save() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let currentStoredEntry = store.entries.first(where: { $0.id == entryID })
        let updated = ExpenseEntry(
            id: entryID,
            rawText: rawText.trimmingCharacters(in: .whitespacesAndNewlines),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            currencyCode: currencyCode,
            transactionKind: transactionKind,
            category: category,
            merchant: merchant.isEmpty ? nil : merchant,
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: needsReview ? .review : .certain,
            isAmountEstimated: needsReview && isAmountEstimated,
            createdAt: createdAt,
            recurringTransactionID: currentStoredEntry?.recurringTransactionID ?? recurringTransactionID,
            recurrenceInstanceKey: currentStoredEntry?.recurrenceInstanceKey ?? recurrenceInstanceKey
        )

        store.updateEntry(updated)
    }

    func recurringDraft(using store: ExpenseJournalStore) -> RecurringTransactionDraft {
        let linkedRecurringTransactionID = store.entries.first(where: { $0.id == entryID })?.recurringTransactionID
            ?? recurringTransactionID

        if let recurringTransaction = store.recurringTransaction(id: linkedRecurringTransactionID) {
            return RecurringTransactionDraft(transaction: recurringTransaction)
        }

        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let entry = ExpenseEntry(
            id: entryID,
            rawText: rawText.trimmingCharacters(in: .whitespacesAndNewlines),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            currencyCode: currencyCode,
            transactionKind: transactionKind,
            category: category,
            merchant: merchant.isEmpty ? nil : merchant,
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: needsReview ? .review : .certain,
            isAmountEstimated: needsReview && isAmountEstimated,
            createdAt: createdAt,
            recurringTransactionID: recurringTransactionID,
            recurrenceInstanceKey: recurrenceInstanceKey
        )

        return RecurringTransactionDraft(entry: entry)
    }
}
