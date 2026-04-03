import Combine
import Foundation

@MainActor
final class ExpenseJournalStore: ObservableObject {
    @Published private(set) var entries: [ExpenseEntry] = []

    private let parser: ExpenseParsingServicing
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let storageKey = "notely.expense.entries"
    private var parseTasksByEntryID: [UUID: Task<Void, Never>] = [:]

    init(
        parser: ExpenseParsingServicing = OpenAIExpenseParsingService(),
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
            resumePendingParsesIfNeeded()
        }
    }

    func addEntry(from rawText: String, on date: Date, currencyCode: String = "NOK") {
        let entry = makePendingEntry(
            rawText: rawText,
            date: date,
            currencyCode: currencyCode,
            createdAt: Date()
        )

        entries.insert(entry, at: 0)
        sortAndPersist()
        scheduleParse(
            entryID: entry.id,
            rawText: entry.rawText,
            date: entry.date,
            currencyCode: entry.currencyCode,
            debounceNanoseconds: 0
        )
    }

    func insertEntry(
        after referenceEntry: ExpenseEntry,
        rawText: String,
        on date: Date,
        currencyCode: String = "NOK"
    ) -> UUID {
        let createdAt = createdAtForInsertion(after: referenceEntry, on: date)
        let entry = makePendingEntry(
            rawText: rawText,
            date: date,
            currencyCode: currencyCode,
            createdAt: createdAt
        )

        entries.insert(entry, at: 0)
        sortAndPersist()
        scheduleParse(
            entryID: entry.id,
            rawText: entry.rawText,
            date: entry.date,
            currencyCode: entry.currencyCode,
            debounceNanoseconds: 0
        )

        return entry.id
    }

    func updateEntry(_ entry: ExpenseEntry, shouldReparseRawText: Bool = false) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            return
        }

        guard entries[index] != entry else {
            return
        }

        entries[index] = entry
        sortAndPersist()

        if shouldReparseRawText {
            scheduleParse(
                entryID: entry.id,
                rawText: entry.rawText,
                date: entry.date,
                currencyCode: entry.currencyCode,
                debounceNanoseconds: 550_000_000
            )
        } else {
            parseTasksByEntryID[entry.id]?.cancel()
            parseTasksByEntryID[entry.id] = nil
        }
    }

    func removeEntry(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return
        }

        parseTasksByEntryID[id]?.cancel()
        parseTasksByEntryID[id] = nil
        entries.remove(at: index)
        persist()
    }

    func clearAllEntries() {
        parseTasksByEntryID.values.forEach { $0.cancel() }
        parseTasksByEntryID.removeAll()
        entries.removeAll()
        persist()
    }

    func entries(on date: Date) -> [ExpenseEntry] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func reparseEntryImmediately(id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else {
            return
        }

        scheduleParse(
            entryID: entry.id,
            rawText: entry.rawText,
            date: entry.date,
            currencyCode: entry.currencyCode,
            debounceNanoseconds: 0
        )
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            entries = Self.mockEntries(calendar: calendar)
            persist()
            return
        }

        guard let decoded = try? JSONDecoder().decode([ExpenseEntry].self, from: data) else {
            entries = []
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

    private func makePendingEntry(
        rawText: String,
        date: Date,
        currencyCode: String,
        createdAt: Date
    ) -> ExpenseEntry {
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        return ExpenseEntry(
            rawText: rawText,
            title: trimmedText.isEmpty ? "Untitled entry" : trimmedText,
            amount: 0,
            currencyCode: currencyCode,
            category: .uncategorized,
            merchant: nil,
            date: date,
            note: "",
            confidence: .uncertain,
            createdAt: createdAt
        )
    }

    private func scheduleParse(
        entryID: UUID,
        rawText: String,
        date: Date,
        currencyCode: String,
        debounceNanoseconds: UInt64
    ) {
        parseTasksByEntryID[entryID]?.cancel()

        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            parseTasksByEntryID[entryID] = nil
            return
        }

        parseTasksByEntryID[entryID] = Task { [weak self] in
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }

            guard !Task.isCancelled, let self else {
                return
            }

            do {
                let draft = try await self.parser.parse(
                    rawText: trimmedText,
                    date: date,
                    currencyCode: currencyCode
                )

                self.applyParsedDraft(
                    draft,
                    entryID: entryID,
                    expectedRawText: rawText,
                    createdCurrencyCode: currencyCode
                )
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                self.markParsingFailed(
                    entryID: entryID,
                    expectedRawText: rawText
                )
            }
        }
    }

    private func applyParsedDraft(
        _ draft: ParsedExpenseDraft,
        entryID: UUID,
        expectedRawText: String,
        createdCurrencyCode: String
    ) {
        parseTasksByEntryID[entryID] = nil

        guard let index = entries.firstIndex(where: { $0.id == entryID }) else {
            return
        }

        guard entries[index].rawText == expectedRawText else {
            return
        }

        let currentEntry = entries[index]
        let resolvedConfidence: ParsingConfidence = draft.amount == 0 && draft.confidence == .uncertain
            ? .review
            : draft.confidence

        entries[index] = ExpenseEntry(
            id: currentEntry.id,
            rawText: currentEntry.rawText,
            title: draft.title.isEmpty ? currentEntry.title : draft.title,
            amount: draft.amount,
            currencyCode: draft.currencyCode.isEmpty ? createdCurrencyCode : draft.currencyCode,
            category: draft.category,
            merchant: draft.merchant?.isEmpty == true ? nil : draft.merchant,
            date: currentEntry.date,
            note: draft.note.isEmpty ? currentEntry.note : draft.note,
            confidence: resolvedConfidence,
            createdAt: currentEntry.createdAt
        )
        sortAndPersist()
    }

    private func markParsingFailed(
        entryID: UUID,
        expectedRawText: String
    ) {
        parseTasksByEntryID[entryID] = nil

        guard let index = entries.firstIndex(where: { $0.id == entryID }) else {
            return
        }

        guard entries[index].rawText == expectedRawText else {
            return
        }

        entries[index].confidence = .review
        persist()
    }

    private func resumePendingParsesIfNeeded() {
        for entry in entries where entry.amount == 0 && !entry.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            scheduleParse(
                entryID: entry.id,
                rawText: entry.rawText,
                date: entry.date,
                currencyCode: entry.currencyCode,
                debounceNanoseconds: 0
            )
        }
    }

    private func createdAtForInsertion(after referenceEntry: ExpenseEntry, on date: Date) -> Date {
        let dayEntries = entries
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { lhs, rhs in
                if calendar.isDate(lhs.date, equalTo: rhs.date, toGranularity: .minute) {
                    return lhs.createdAt < rhs.createdAt
                }

                return lhs.date < rhs.date
            }

        guard
            let referenceIndex = dayEntries.firstIndex(where: { $0.id == referenceEntry.id })
        else {
            return max(Date(), referenceEntry.createdAt.addingTimeInterval(0.001))
        }

        guard referenceIndex + 1 < dayEntries.count else {
            return max(Date(), referenceEntry.createdAt.addingTimeInterval(0.001))
        }

        let nextCreatedAt = dayEntries[referenceIndex + 1].createdAt
        let delta = nextCreatedAt.timeIntervalSince(referenceEntry.createdAt)

        if delta > 0 {
            return referenceEntry.createdAt.addingTimeInterval(delta / 2)
        }

        return referenceEntry.createdAt.addingTimeInterval(0.001)
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
