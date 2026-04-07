import Combine
import Foundation

@MainActor
final class ExpenseJournalStore: ObservableObject {
    @Published private(set) var entries: [ExpenseEntry] = []
    @Published private(set) var budgetPlan: BudgetPlan = .empty

    private let parser: ExpenseParsingServicing
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let storageKey = "notely.expense.entries"
    private let budgetPlanStorageKey = "notely.expense.budget-plan"
    private let parseCacheStorageKey = "notely.expense.parse-cache"
    private let maxParseCacheEntryCount = 300
    private var parseTasksByEntryID: [UUID: Task<Void, Never>] = [:]
    private var parseCacheByKey: [String: ParsedExpenseDraft] = [:]

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
            budgetPlan = Self.mockBudgetPlan
        } else {
            load()
            loadBudgetPlan()
            loadParseCache()
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
            debounceNanoseconds: 0,
            sendsHapticFeedback: true
        )
    }

    func insertEntry(
        after referenceEntry: ExpenseEntry,
        rawText: String,
        on date: Date,
        currencyCode: String = "NOK"
    ) -> UUID {
        let nextEntry = nextEntry(after: referenceEntry, on: date)

        return insertEntry(
            between: referenceEntry,
            and: nextEntry,
            rawText: rawText,
            on: date,
            currencyCode: currencyCode
        )
    }

    func insertEntry(
        between previousEntry: ExpenseEntry?,
        and nextEntry: ExpenseEntry?,
        rawText: String,
        on date: Date,
        currencyCode: String = "NOK"
    ) -> UUID {
        let createdAt = createdAtForInsertion(
            between: previousEntry,
            and: nextEntry,
            on: date
        )
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
            debounceNanoseconds: 0,
            sendsHapticFeedback: true
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
                debounceNanoseconds: 550_000_000,
                sendsHapticFeedback: true
            )
        } else {
            parseTasksByEntryID[entry.id]?.cancel()
            parseTasksByEntryID[entry.id] = nil
            cacheManuallyVerifiedEntryIfNeeded(entry)
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
        parseCacheByKey.removeAll()
        entries.removeAll()
        persist()
        persistParseCache()
    }

    func setMonthlySpendingLimit(_ amount: Double) {
        budgetPlan.setMonthlySpendingLimit(amount)
        persistBudgetPlan()
    }

    func setMonthlySavingsTarget(_ amount: Double) {
        budgetPlan.setMonthlySavingsTarget(amount)
        persistBudgetPlan()
    }

    func setCategoryBudget(_ amount: Double, for category: ExpenseCategory) {
        budgetPlan.setCategoryTarget(amount, for: category)
        persistBudgetPlan()
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
            debounceNanoseconds: 0,
            sendsHapticFeedback: true
        )
    }

    func previewDraft(
        rawText: String,
        on date: Date,
        currencyCode: String = "NOK"
    ) async throws -> ParsedExpenseDraft {
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw ExpenseParsingServiceError.emptyModelResponse
        }

        let cacheKey = parseCacheKey(rawText: trimmedText, currencyCode: currencyCode)
        if let cachedDraft = parseCacheByKey[cacheKey] {
            return ParsedExpenseDraft(
                rawText: trimmedText,
                title: cachedDraft.title,
                amount: cachedDraft.amount,
                currencyCode: cachedDraft.currencyCode,
                transactionKind: cachedDraft.transactionKind,
                category: cachedDraft.category,
                merchant: cachedDraft.merchant,
                note: cachedDraft.note,
                confidence: cachedDraft.confidence,
                isAmountEstimated: cachedDraft.isAmountEstimated
            )
        }

        let draft = try await parseWithRetry(
            rawText: trimmedText,
            date: date,
            currencyCode: currencyCode
        )
        cacheParsedDraft(draft, for: cacheKey)
        return draft
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

    private func loadBudgetPlan() {
        guard let data = defaults.data(forKey: budgetPlanStorageKey),
              let decoded = try? JSONDecoder().decode(BudgetPlan.self, from: data) else {
            budgetPlan = .empty
            return
        }

        budgetPlan = decoded
    }

    private func persistBudgetPlan() {
        guard let data = try? JSONEncoder().encode(budgetPlan) else {
            return
        }

        defaults.set(data, forKey: budgetPlanStorageKey)
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
            title: trimmedText.isEmpty ? "Untitled entry".notyfiLocalized : trimmedText,
            amount: 0,
            currencyCode: currencyCode,
            transactionKind: .expense,
            category: .uncategorized,
            merchant: nil,
            date: date,
            note: "",
            confidence: .uncertain,
            isAmountEstimated: false,
            createdAt: createdAt
        )
    }

    private func scheduleParse(
        entryID: UUID,
        rawText: String,
        date: Date,
        currencyCode: String,
        debounceNanoseconds: UInt64,
        sendsHapticFeedback: Bool
    ) {
        parseTasksByEntryID[entryID]?.cancel()

        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            parseTasksByEntryID[entryID] = nil
            return
        }

        let cacheKey = parseCacheKey(rawText: trimmedText, currencyCode: currencyCode)
        if let cachedDraft = parseCacheByKey[cacheKey] {
            parseTasksByEntryID[entryID] = nil
                applyParsedDraft(
                    ParsedExpenseDraft(
                        rawText: trimmedText,
                    title: cachedDraft.title,
                    amount: cachedDraft.amount,
                    currencyCode: cachedDraft.currencyCode,
                    transactionKind: cachedDraft.transactionKind,
                    category: cachedDraft.category,
                    merchant: cachedDraft.merchant,
                    note: cachedDraft.note,
                    confidence: cachedDraft.confidence,
                    isAmountEstimated: cachedDraft.isAmountEstimated
                    ),
                    entryID: entryID,
                    expectedRawText: rawText,
                    createdCurrencyCode: currencyCode,
                    sendsHapticFeedback: sendsHapticFeedback
                )
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
                let draft = try await self.parseWithRetry(
                    rawText: trimmedText,
                    date: date,
                    currencyCode: currencyCode
                )

                guard !Task.isCancelled else {
                    return
                }

                self.cacheParsedDraft(draft, for: cacheKey)

                self.applyParsedDraft(
                    draft,
                    entryID: entryID,
                    expectedRawText: rawText,
                    createdCurrencyCode: currencyCode,
                    sendsHapticFeedback: sendsHapticFeedback
                )
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                self.markParsingFailed(
                    entryID: entryID,
                    expectedRawText: rawText,
                    error: error
                )
            }
        }
    }

    private func applyParsedDraft(
        _ draft: ParsedExpenseDraft,
        entryID: UUID,
        expectedRawText: String,
        createdCurrencyCode: String,
        sendsHapticFeedback: Bool
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
            transactionKind: draft.transactionKind,
            category: draft.category,
            merchant: draft.merchant?.isEmpty == true ? nil : draft.merchant,
            date: currentEntry.date,
            note: draft.note.isEmpty ? currentEntry.note : draft.note,
            confidence: resolvedConfidence,
            isAmountEstimated: draft.isAmountEstimated,
            createdAt: currentEntry.createdAt
        )
        sortAndPersist()

        if sendsHapticFeedback {
            Haptics.lightImpact()
        }
    }

    private func markParsingFailed(
        entryID: UUID,
        expectedRawText: String,
        error: Error
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
                debounceNanoseconds: 0,
                sendsHapticFeedback: false
            )
        }
    }

    private func parseWithRetry(
        rawText: String,
        date: Date,
        currencyCode: String
    ) async throws -> ParsedExpenseDraft {
        do {
            return try await parser.parse(
                rawText: rawText,
                date: date,
                currencyCode: currencyCode
            )
        } catch {
            guard shouldRetryParsing(after: error), !Task.isCancelled else {
                throw error
            }

            try await Task.sleep(nanoseconds: 700_000_000)

            guard !Task.isCancelled else {
                throw error
            }

            return try await parser.parse(
                rawText: rawText,
                date: date,
                currencyCode: currencyCode
            )
        }
    }

    private func shouldRetryParsing(after error: Error) -> Bool {
        if let parsingError = error as? OpenAIExpenseParsingService.RequestError {
            return parsingError.isRetryable
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                .cannotFindHost,
                .cannotConnectToHost,
                .networkConnectionLost,
                .dnsLookupFailed,
                .notConnectedToInternet,
                .internationalRoamingOff,
                .callIsActive,
                .dataNotAllowed:
                return true
            default:
                return false
            }
        }

        return false
    }

    private func cacheParsedDraft(_ draft: ParsedExpenseDraft, for cacheKey: String) {
        parseCacheByKey[cacheKey] = ParsedExpenseDraft(
            rawText: cacheKey,
            title: draft.title,
            amount: draft.amount,
            currencyCode: draft.currencyCode,
            transactionKind: draft.transactionKind,
            category: draft.category,
            merchant: draft.merchant,
            note: draft.note,
            confidence: draft.confidence,
            isAmountEstimated: draft.isAmountEstimated
        )

        if parseCacheByKey.count > maxParseCacheEntryCount {
            let overflowCount = parseCacheByKey.count - maxParseCacheEntryCount
            let keysToRemove = parseCacheByKey.keys.prefix(overflowCount)
            keysToRemove.forEach { parseCacheByKey.removeValue(forKey: $0) }
        }

        persistParseCache()
    }

    private func cacheManuallyVerifiedEntryIfNeeded(_ entry: ExpenseEntry) {
        let trimmedText = entry.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedText.isEmpty,
            entry.amount > 0,
            entry.confidence == .certain
        else {
            return
        }

        cacheParsedDraft(
            ParsedExpenseDraft(
                rawText: trimmedText,
                title: entry.title,
                amount: entry.amount,
                currencyCode: entry.currencyCode,
                transactionKind: entry.transactionKind,
                category: entry.category,
                merchant: entry.merchant,
                note: entry.note,
                confidence: entry.confidence,
                isAmountEstimated: false
            ),
            for: parseCacheKey(rawText: trimmedText, currencyCode: entry.currencyCode)
        )
    }

    private func parseCacheKey(rawText: String, currencyCode: String) -> String {
        let normalizedText = rawText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        return "\(currencyCode.uppercased())|\(normalizedText)"
    }

    private func loadParseCache() {
        guard let data = defaults.data(forKey: parseCacheStorageKey),
              let decoded = try? JSONDecoder().decode([String: ParsedExpenseDraft].self, from: data) else {
            parseCacheByKey = [:]
            return
        }

        parseCacheByKey = decoded
    }

    private func persistParseCache() {
        guard let data = try? JSONEncoder().encode(parseCacheByKey) else {
            return
        }

        defaults.set(data, forKey: parseCacheStorageKey)
    }

    private func createdAtForInsertion(
        between previousEntry: ExpenseEntry?,
        and nextEntry: ExpenseEntry?,
        on date: Date
    ) -> Date {
        switch (previousEntry, nextEntry) {
        case let (previous?, next?):
            let delta = next.createdAt.timeIntervalSince(previous.createdAt)

            if delta > 0 {
                return previous.createdAt.addingTimeInterval(delta / 2)
            }

            return previous.createdAt.addingTimeInterval(0.001)
        case let (previous?, nil):
            return previous.createdAt.addingTimeInterval(0.001)
        case let (nil, next?):
            return next.createdAt.addingTimeInterval(-0.001)
        case (nil, nil):
            let dayEntries = entries(on: date).sorted { lhs, rhs in
                lhs.createdAt < rhs.createdAt
            }

            if let firstEntry = dayEntries.first {
                return firstEntry.createdAt.addingTimeInterval(-0.001)
            }

            return Date()
        }
    }

    private func nextEntry(after referenceEntry: ExpenseEntry, on date: Date) -> ExpenseEntry? {
        let dayEntries = entries(on: date).sorted { lhs, rhs in
            lhs.createdAt < rhs.createdAt
        }

        guard let referenceIndex = dayEntries.firstIndex(where: { $0.id == referenceEntry.id }) else {
            return nil
        }

        guard referenceIndex + 1 < dayEntries.count else {
            return nil
        }

        return dayEntries[referenceIndex + 1]
    }
}

private extension ExpenseJournalStore {
    static let mockBudgetPlan = BudgetPlan(
        monthlySpendingLimit: 15000,
        monthlySavingsTarget: 5000,
        categoryTargets: [
            BudgetCategoryTarget(category: .housing, amount: 12000),
            BudgetCategoryTarget(category: .food, amount: 1800),
            BudgetCategoryTarget(category: .transport, amount: 1200),
            BudgetCategoryTarget(category: .social, amount: 1500)
        ]
    )

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
                transactionKind: .expense,
                category: .food,
                merchant: "Talormade",
                date: morning,
                note: "Quick stop before the train.",
                confidence: .certain,
                isAmountEstimated: false
            ),
            ExpenseEntry(
                rawText: "Train ticket 299",
                title: "Train ticket",
                amount: 299,
                transactionKind: .expense,
                category: .transport,
                merchant: "Vy",
                date: noon,
                note: "",
                confidence: .review,
                isAmountEstimated: false
            ),
            ExpenseEntry(
                rawText: "Dinner at McDonald's 145",
                title: "Dinner",
                amount: 145,
                transactionKind: .expense,
                category: .food,
                merchant: "McDonald's",
                date: evening,
                note: "Late dinner after work.",
                confidence: .certain,
                isAmountEstimated: false
            ),
            ExpenseEntry(
                rawText: "Split dinner with friends 320",
                title: "Split dinner with friends",
                amount: 320,
                transactionKind: .expense,
                category: .social,
                merchant: nil,
                date: yesterday,
                note: "Needs a quick review before export.",
                confidence: .review,
                isAmountEstimated: false
            ),
            ExpenseEntry(
                rawText: "Rent 12000",
                title: "Rent",
                amount: 12000,
                transactionKind: .expense,
                category: .housing,
                merchant: nil,
                date: earlier,
                note: "",
                confidence: .certain,
                isAmountEstimated: false
            ),
            ExpenseEntry(
                rawText: "Salary 28000",
                title: "Salary",
                amount: 28000,
                transactionKind: .income,
                category: .uncategorized,
                merchant: "Employer",
                date: calendar.date(byAdding: .day, value: -5, to: morning) ?? morning,
                note: "",
                confidence: .certain,
                isAmountEstimated: false
            )
        ].sorted { $0.date > $1.date }
    }
}
