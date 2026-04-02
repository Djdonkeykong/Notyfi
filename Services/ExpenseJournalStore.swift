import Combine
import Foundation

@MainActor
final class ExpenseJournalStore: ObservableObject {
    @Published private(set) var entries: [ExpenseEntry] = []

    private let parser: ExpenseParsingServicing
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let storageKey = "notely.expense.entries"

    init(
        parser: ExpenseParsingServicing = PlaceholderExpenseParsingService(),
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        previewMode: Bool = false
    ) {
        self.parser = parser
        self.defaults = defaults
        self.calendar = calendar

        if previewMode {
            entries = Self.mockEntries(calendar: calendar)
        } else {
            load()
        }
    }

    func addEntry(from rawText: String, on date: Date, currencyCode: String = "NOK") {
        let draft = parser.parse(rawText: rawText, date: date, currencyCode: currencyCode)
        let entry = ExpenseEntry(
            rawText: draft.rawText,
            title: draft.title,
            amount: draft.amount,
            currencyCode: draft.currencyCode,
            category: draft.category,
            merchant: draft.merchant,
            date: date,
            note: draft.note,
            confidence: draft.confidence
        )

        entries.insert(entry, at: 0)
        sortAndPersist()
    }

    func updateEntry(_ entry: ExpenseEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            return
        }

        entries[index] = entry
        sortAndPersist()
    }

    func removeEntry(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return
        }

        entries.remove(at: index)
        persist()
    }

    func clearAllEntries() {
        entries.removeAll()
        persist()
    }

    func entries(on date: Date) -> [ExpenseEntry] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func load() {
        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([ExpenseEntry].self, from: data),
            !decoded.isEmpty
        else {
            entries = Self.mockEntries(calendar: calendar)
            persist()
            return
        }

        entries = decoded.sorted { $0.date > $1.date }
    }

    private func sortAndPersist() {
        entries.sort { lhs, rhs in
            if calendar.isDate(lhs.date, equalTo: rhs.date, toGranularity: .minute) {
                return lhs.createdAt > rhs.createdAt
            }

            return lhs.date > rhs.date
        }

        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }
}

private extension ExpenseJournalStore {
    static func mockEntries(calendar: Calendar) -> [ExpenseEntry] {
        let today = Date()
        let morning = calendar.date(bySettingHour: 8, minute: 40, second: 0, of: today) ?? today
        let noon = calendar.date(bySettingHour: 12, minute: 15, second: 0, of: today) ?? today
        let evening = calendar.date(bySettingHour: 19, minute: 10, second: 0, of: today) ?? today
        let yesterday = calendar.date(byAdding: .day, value: -1, to: evening) ?? evening
        let earlier = calendar.date(byAdding: .day, value: -3, to: noon) ?? noon

        return [
            ExpenseEntry(
                rawText: "Coffee 49 kr",
                title: "Coffee",
                amount: 49,
                category: .food,
                merchant: "Talormade",
                date: morning,
                note: "Quick stop before the train.",
                confidence: .certain
            ),
            ExpenseEntry(
                rawText: "Train ticket 299",
                title: "Train ticket",
                amount: 299,
                category: .transport,
                merchant: "Vy",
                date: noon,
                note: "",
                confidence: .review
            ),
            ExpenseEntry(
                rawText: "Dinner at McDonald's 145",
                title: "Dinner",
                amount: 145,
                category: .food,
                merchant: "McDonald's",
                date: evening,
                note: "Late dinner after work.",
                confidence: .certain
            ),
            ExpenseEntry(
                rawText: "Split dinner with friends 320",
                title: "Split dinner with friends",
                amount: 320,
                category: .social,
                merchant: nil,
                date: yesterday,
                note: "Needs a quick review before export.",
                confidence: .review
            ),
            ExpenseEntry(
                rawText: "Rent 12000",
                title: "Rent",
                amount: 12000,
                category: .housing,
                merchant: nil,
                date: earlier,
                note: "",
                confidence: .certain
            )
        ].sorted { $0.date > $1.date }
    }
}
