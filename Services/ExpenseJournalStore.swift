import Combine
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class ExpenseJournalStore: ObservableObject {
    @Published private(set) var entries: [ExpenseEntry] = []
    @Published private(set) var budgetPlan: BudgetPlan = .empty
    @Published private(set) var trackedCategories: Set<ExpenseCategory> = []
    @Published private(set) var effectiveTrackedCategories: Set<ExpenseCategory> = Set(ExpenseCategory.trackableCases)
    @Published private(set) var recurringTransactions: [RecurringTransaction] = []

    private let parser: ExpenseParsingServicing
    private let defaults: UserDefaults
    private let sharedDefaults: UserDefaults
    private let calendar: Calendar
    private let storageKey = "notely.expense.entries"
    private let budgetPlanStorageKey = "notely.expense.budget-plan"
    private let trackedCategoriesStorageKey = "notely.expense.tracked-categories"
    private let recurringTransactionsStorageKey = "notely.expense.recurring-transactions"
    private let parseCacheStorageKey = "notely.expense.parse-cache"
    private let maxParseCacheEntryCount = 300
    private var hasStoredTrackedCategories = false
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
        self.sharedDefaults = NotyfiSharedStorage.sharedDefaults()
        self.calendar = calendar

        if previewMode {
            entries = Self.mockEntries(calendar: calendar)
            budgetPlan = Self.mockBudgetPlan
            trackedCategories = Set(Self.mockBudgetPlan.categoryTargets.map(\.category))
            recurringTransactions = Self.mockRecurringTransactions(calendar: calendar)
            hasStoredTrackedCategories = true
            effectiveTrackedCategories = trackedCategories
            _ = materializeDueRecurringEntries(upTo: Date())
            updateSharedSurfaces()
        } else {
            load()
            loadBudgetPlan()
            loadTrackedCategories()
            loadRecurringTransactions()
            loadParseCache()
            _ = materializeDueRecurringEntries(upTo: Date())
            resumePendingParsesIfNeeded()
            updateSharedSurfaces()
        }
    }

    func addEntry(from rawText: String, on date: Date, currencyCode: String = NotyfiCurrency.currentCode()) {
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

    func addManualEntry(_ entry: ExpenseEntry) {
        entries.insert(entry, at: 0)
        sortAndPersist()
    }

    func insertEntry(
        after referenceEntry: ExpenseEntry,
        rawText: String,
        on date: Date,
        currencyCode: String = NotyfiCurrency.currentCode()
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
        currencyCode: String = NotyfiCurrency.currentCode()
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

        if shouldReparseRawText {
            var reparsingEntry = entry
            reparsingEntry.amount = 0
            reparsingEntry.category = .uncategorized
            reparsingEntry.merchant = nil
            reparsingEntry.note = ""
            reparsingEntry.confidence = .uncertain
            reparsingEntry.isAmountEstimated = false
            entries[index] = reparsingEntry
        } else {
            entries[index] = entry
        }
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

        let recurringID = entries[index].recurringTransactionID
        parseTasksByEntryID[id]?.cancel()
        parseTasksByEntryID[id] = nil
        entries.remove(at: index)
        persist()

        if let recurringID {
            removeRecurringTransaction(id: recurringID)
        }
    }

    func clearAllEntries() {
        parseTasksByEntryID.values.forEach { $0.cancel() }
        parseTasksByEntryID.removeAll()
        parseCacheByKey.removeAll()
        entries.removeAll()
        recurringTransactions.removeAll()
        persist()
        persistParseCache()
        persistRecurringTransactions()
        updateSharedSurfaces()
    }

    func resetForSignOut() {
        parseTasksByEntryID.values.forEach { $0.cancel() }
        parseTasksByEntryID.removeAll()
        parseCacheByKey.removeAll()
        entries.removeAll()
        recurringTransactions.removeAll()
        budgetPlan = .empty
        trackedCategories = []
        effectiveTrackedCategories = Set(ExpenseCategory.trackableCases)
        hasStoredTrackedCategories = false
        persist()
        persistBudgetPlan()
        persistTrackedCategories()
        persistRecurringTransactions()
        persistParseCache()
        updateSharedSurfaces()
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

    func setTrackedCategories(_ categories: Set<ExpenseCategory>) {
        hasStoredTrackedCategories = true
        let filtered = Set(categories.filter { $0 != .uncategorized })
        trackedCategories = filtered
        effectiveTrackedCategories = filtered
        persistTrackedCategories()
    }

    func saveRecurringTransaction(
        _ recurringTransaction: RecurringTransaction,
        materializeDueEntries: Bool = true
    ) {
        var nextRecurringTransactions = recurringTransactions

        if let index = nextRecurringTransactions.firstIndex(where: { $0.id == recurringTransaction.id }) {
            nextRecurringTransactions[index] = recurringTransaction
        } else {
            nextRecurringTransactions.append(recurringTransaction)
        }

        recurringTransactions = sortedRecurringTransactions(nextRecurringTransactions)
        persistRecurringTransactions()

        if materializeDueEntries {
            _ = materializeDueRecurringEntries(upTo: Date())
        }
    }

    func removeRecurringTransaction(id: UUID) {
        recurringTransactions.removeAll { $0.id == id }
        persistRecurringTransactions()

        let updatedEntries = entries.map { entry -> ExpenseEntry in
            guard entry.recurringTransactionID == id else {
                return entry
            }

            var updatedEntry = entry
            updatedEntry.recurringTransactionID = nil
            updatedEntry.recurrenceInstanceKey = nil
            return updatedEntry
        }

        if updatedEntries != entries {
            entries = updatedEntries
            sortAndPersist()
        }
    }

    func recurringTransaction(id: UUID?) -> RecurringTransaction? {
        guard let id else {
            return nil
        }

        return recurringTransactions.first(where: { $0.id == id })
    }

    @discardableResult
    func materializeDueRecurringEntries(upTo referenceDate: Date = Date()) -> Bool {
        guard !recurringTransactions.isEmpty else {
            return false
        }

        var nextEntries = entries
        var nextRecurringTransactions = recurringTransactions
        let generatedAt = Date()
        var didChangeEntries = false
        var didChangeRecurringTransactions = false

        for index in nextRecurringTransactions.indices {
            let recurringTransaction = nextRecurringTransactions[index]
            let dueDates = recurringTransaction.dueOccurrenceDates(
                upTo: referenceDate,
                calendar: calendar
            )

            guard !dueDates.isEmpty else {
                continue
            }

            for occurrenceDate in dueDates {
                let instanceKey = RecurringTransaction.recurrenceInstanceKey(
                    recurringTransactionID: recurringTransaction.id,
                    occurrenceDate: occurrenceDate
                )

                guard !nextEntries.contains(where: { $0.recurrenceInstanceKey == instanceKey }) else {
                    continue
                }

                nextEntries.append(
                    recurringTransaction.recurringEntry(
                        for: occurrenceDate
                    )
                )
                didChangeEntries = true
            }

            nextRecurringTransactions[index] = recurringTransaction.advancingPastDueOccurrences(
                dueDates,
                generatedAt: generatedAt,
                calendar: calendar
            )
            didChangeRecurringTransactions = true
        }

        if didChangeRecurringTransactions {
            recurringTransactions = sortedRecurringTransactions(nextRecurringTransactions)
            persistRecurringTransactions()
        }

        if didChangeEntries {
            entries = nextEntries
            sortAndPersist()
        }

        return didChangeEntries || didChangeRecurringTransactions
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
        currencyCode: String = NotyfiCurrency.currentCode()
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
                isAmountEstimated: cachedDraft.isAmountEstimated,
                isRecurring: cachedDraft.isRecurring,
                recurringFrequency: cachedDraft.recurringFrequency
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

    func importEntries(
        from imageData: Data,
        mimeType: String,
        on date: Date,
        currencyCode: String = NotyfiCurrency.currentCode()
    ) async throws -> [UUID] {
        let drafts = try await parseImageWithRetry(
            imageData: imageData,
            mimeType: mimeType,
            date: date,
            currencyCode: currencyCode
        )

        let timestampSeed = Date()
        let importedEntries = drafts.enumerated().map { index, draft in
            let createdAt = timestampSeed.addingTimeInterval(Double(index) * 0.001)
            let entry = importedEntry(
                from: draft,
                on: date,
                fallbackCurrencyCode: currencyCode,
                createdAt: createdAt
            )

            return linkRecurringTransactionIfNeeded(
                for: entry,
                parsedDraft: draft,
                createdAt: createdAt
            )
        }

        entries.insert(contentsOf: importedEntries, at: 0)
        sortAndPersist()
        _ = materializeDueRecurringEntries(upTo: Date())
        Haptics.lightImpact()

        return importedEntries.map(\.id)
    }

    func replaceAll(
        entries: [ExpenseEntry],
        budgetPlan: BudgetPlan,
        trackedCategories: Set<ExpenseCategory>,
        recurringTransactions: [RecurringTransaction]
    ) {
        parseTasksByEntryID.values.forEach { $0.cancel() }
        parseTasksByEntryID.removeAll()

        self.entries = entries
        self.budgetPlan = budgetPlan
        let filteredCategories = Set(trackedCategories.filter { $0 != .uncategorized })
        self.trackedCategories = filteredCategories
        self.recurringTransactions = sortedRecurringTransactions(recurringTransactions)
        hasStoredTrackedCategories = true
        effectiveTrackedCategories = filteredCategories

        sortAndPersist()
        persistBudgetPlan()
        persistTrackedCategories()
        persistRecurringTransactions()
        updateSharedSurfaces()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            entries = []
            persist()
            return
        }

        guard let decoded = try? JSONDecoder().decode([ExpenseEntry].self, from: data) else {
            entries = []
            persist()
            return
        }

        entries = decoded.sorted { lhs, rhs in
            if calendar.isDate(lhs.date, equalTo: rhs.date, toGranularity: .minute) {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.date > rhs.date
        }
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
        updateSharedSurfaces()
    }

    private func loadBudgetPlan() {
        guard let data = defaults.data(forKey: budgetPlanStorageKey),
              let decoded = try? JSONDecoder().decode(BudgetPlan.self, from: data) else {
            budgetPlan = .empty
            return
        }

        budgetPlan = decoded
    }

    private func loadTrackedCategories() {
        guard let data = defaults.data(forKey: trackedCategoriesStorageKey),
              let decoded = try? JSONDecoder().decode([ExpenseCategory].self, from: data) else {
            trackedCategories = []
            hasStoredTrackedCategories = false
            return
        }

        trackedCategories = Set(decoded.filter { $0 != .uncategorized })
        hasStoredTrackedCategories = true
        effectiveTrackedCategories = trackedCategories
    }

    private func loadRecurringTransactions() {
        guard let data = defaults.data(forKey: recurringTransactionsStorageKey),
              let decoded = try? JSONDecoder().decode([RecurringTransaction].self, from: data) else {
            recurringTransactions = []
            return
        }

        recurringTransactions = sortedRecurringTransactions(decoded)
    }

    private func persistBudgetPlan() {
        guard let data = try? JSONEncoder().encode(budgetPlan) else {
            return
        }

        defaults.set(data, forKey: budgetPlanStorageKey)
        updateSharedSurfaces()
    }

    private func persistTrackedCategories() {
        let orderedCategories = ExpenseCategory.trackableCases.filter { trackedCategories.contains($0) }
        guard let data = try? JSONEncoder().encode(orderedCategories) else {
            return
        }

        defaults.set(data, forKey: trackedCategoriesStorageKey)
    }

    private func persistRecurringTransactions() {
        guard let data = try? JSONEncoder().encode(recurringTransactions) else {
            return
        }

        defaults.set(data, forKey: recurringTransactionsStorageKey)
    }

    private func updateSharedSurfaces() {
        let snapshot = makeFinanceSnapshot(referenceDate: Date())
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }

        sharedDefaults.set(data, forKey: NotyfiSharedStorage.financeSnapshotKey)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func makeFinanceSnapshot(referenceDate: Date) -> NotyfiFinanceSnapshot {
        let activeCurrencyCode = NotyfiCurrency.currentCode(defaults: defaults)
        let todayEntries = entries.filter {
            calendar.isDate($0.date, inSameDayAs: referenceDate)
                && $0.currencyCode.caseInsensitiveCompare(activeCurrencyCode) == .orderedSame
        }
        let monthEntries = entries.filter {
            calendar.isDate($0.date, equalTo: referenceDate, toGranularity: .month)
                && $0.currencyCode.caseInsensitiveCompare(activeCurrencyCode) == .orderedSame
        }

        let todaySpent = todayEntries
            .filter { $0.transactionKind == .expense }
            .reduce(0) { $0 + $1.amount }
        let monthSpent = monthEntries
            .filter { $0.transactionKind == .expense }
            .reduce(0) { $0 + $1.amount }
        let monthIncome = monthEntries
            .filter { $0.transactionKind == .income }
            .reduce(0) { $0 + $1.amount }
        let monthNet = monthIncome - monthSpent
        let hasBudget = budgetPlan.monthlySpendingLimit > 0
        let budgetLeft = hasBudget ? budgetPlan.monthlySpendingLimit - monthSpent : 0

        return NotyfiFinanceSnapshot(
            generatedAt: referenceDate,
            currencyCode: monthEntries.first?.currencyCode ?? activeCurrencyCode,
            todaySpent: todaySpent,
            monthSpent: monthSpent,
            monthIncome: monthIncome,
            monthNet: monthNet,
            monthlyBudgetLimit: budgetPlan.monthlySpendingLimit,
            budgetLeft: budgetLeft,
            hasBudget: hasBudget,
            hasEntries: !entries.isEmpty
        )
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
                    isAmountEstimated: cachedDraft.isAmountEstimated,
                    isRecurring: cachedDraft.isRecurring,
                    recurringFrequency: cachedDraft.recurringFrequency
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

        var updatedEntry = ExpenseEntry(
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
            createdAt: currentEntry.createdAt,
            recurringTransactionID: currentEntry.recurringTransactionID,
            recurrenceInstanceKey: currentEntry.recurrenceInstanceKey
        )

        let linkedEntry = linkRecurringTransactionIfNeeded(
            for: updatedEntry,
            parsedDraft: draft,
            createdAt: currentEntry.createdAt
        )
        let shouldMaterializeRecurring = linkedEntry.recurringTransactionID != currentEntry.recurringTransactionID
        updatedEntry = linkedEntry
        entries[index] = updatedEntry
        sortAndPersist()

        if shouldMaterializeRecurring {
            _ = materializeDueRecurringEntries(upTo: Date())
        }

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

    private func parseImageWithRetry(
        imageData: Data,
        mimeType: String,
        date: Date,
        currencyCode: String
    ) async throws -> [ParsedExpenseDraft] {
        do {
            return try await parser.parse(
                imageData: imageData,
                mimeType: mimeType,
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
                imageData: imageData,
                mimeType: mimeType,
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
            isAmountEstimated: draft.isAmountEstimated,
            isRecurring: draft.isRecurring,
            recurringFrequency: draft.recurringFrequency
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
                isAmountEstimated: false,
                isRecurring: false,
                recurringFrequency: nil
            ),
            for: parseCacheKey(rawText: trimmedText, currencyCode: entry.currencyCode)
        )
    }

    private func linkRecurringTransactionIfNeeded(
        for entry: ExpenseEntry,
        parsedDraft: ParsedExpenseDraft,
        createdAt: Date
    ) -> ExpenseEntry {
        guard parsedDraft.isRecurring, entry.amount > 0, entry.recurringTransactionID == nil else {
            return entry
        }

        let frequency = parsedDraft.recurringFrequency ?? .monthly

        if let existingRecurringTransaction = matchingRecurringTransaction(
            for: entry,
            frequency: frequency
        ) {
            let instanceKey = RecurringTransaction.recurrenceInstanceKey(
                recurringTransactionID: existingRecurringTransaction.id,
                occurrenceDate: existingRecurringTransaction.nextOccurrenceAt
            )

            guard !entries.contains(where: {
                $0.id != entry.id && $0.recurrenceInstanceKey == instanceKey
            }) else {
                return entry
            }

            var linkedEntry = entry
            linkedEntry.recurringTransactionID = existingRecurringTransaction.id
            linkedEntry.recurrenceInstanceKey = instanceKey
            return linkedEntry
        }

        var recurringDraft = RecurringTransactionDraft(entry: entry)
        recurringDraft.frequency = frequency

        let preferredTemplate = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !preferredTemplate.isEmpty {
            recurringDraft.rawTextTemplate = preferredTemplate
        }

        let recurringTransaction = recurringDraft.recurringTransaction(
            calendar: calendar,
            now: createdAt
        )

        saveRecurringTransaction(
            recurringTransaction,
            materializeDueEntries: false
        )

        var linkedEntry = entry
        linkedEntry.recurringTransactionID = recurringTransaction.id
        linkedEntry.recurrenceInstanceKey = RecurringTransaction.recurrenceInstanceKey(
            recurringTransactionID: recurringTransaction.id,
            occurrenceDate: entry.date
        )
        return linkedEntry
    }

    private func matchingRecurringTransaction(
        for entry: ExpenseEntry,
        frequency: RecurringFrequency
    ) -> RecurringTransaction? {
        let normalizedTitle = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedMerchant = entry.merchant?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return recurringTransactions.first { recurringTransaction in
            recurringTransaction.frequency == frequency
                && recurringTransaction.transactionKind == entry.transactionKind
                && recurringTransaction.category == entry.category
                && abs(recurringTransaction.amount - entry.amount) < 0.0001
                && recurringTransaction.currencyCode.caseInsensitiveCompare(entry.currencyCode) == .orderedSame
                && calendar.isDate(recurringTransaction.nextOccurrenceAt, inSameDayAs: entry.date)
                && recurringTransaction.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(normalizedTitle) == .orderedSame
                && recurringTransaction.merchant?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() == normalizedMerchant
        }
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

    private func importedEntry(
        from draft: ParsedExpenseDraft,
        on date: Date,
        fallbackCurrencyCode: String,
        createdAt: Date
    ) -> ExpenseEntry {
        let rawText = normalizedImportedJournalText(draft.rawText)
        let title = normalizedImportedJournalText(draft.title)
        let resolvedConfidence: ParsingConfidence = draft.amount == 0 && draft.confidence == .uncertain
            ? .review
            : draft.confidence

        return ExpenseEntry(
            rawText: rawText.isEmpty ? (title.isEmpty ? "Imported note".notyfiLocalized : title) : rawText,
            title: title.isEmpty ? (rawText.isEmpty ? "Imported note".notyfiLocalized : rawText) : title,
            amount: draft.amount,
            currencyCode: draft.currencyCode.isEmpty ? fallbackCurrencyCode : draft.currencyCode,
            transactionKind: draft.transactionKind,
            category: draft.category,
            merchant: draft.merchant?.isEmpty == true ? nil : draft.merchant,
            date: date,
            note: draft.note,
            confidence: resolvedConfidence,
            isAmountEstimated: draft.isAmountEstimated,
            createdAt: createdAt
        )
    }

    private func normalizedImportedJournalText(_ text: String) -> String {
        let collapsedWhitespace = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return collapsedWhitespace.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func sortedRecurringTransactions(_ transactions: [RecurringTransaction]) -> [RecurringTransaction] {
        transactions.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive && !rhs.isActive
            }

            if lhs.nextOccurrenceAt == rhs.nextOccurrenceAt {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

            return lhs.nextOccurrenceAt < rhs.nextOccurrenceAt
        }
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

    static func mockRecurringTransactions(calendar: Calendar) -> [RecurringTransaction] {
        let now = Date()
        let nextBillDate = calendar.date(byAdding: .day, value: 5, to: now) ?? now

        return [
            RecurringTransaction(
                id: UUID(),
                title: "Streaming",
                rawTextTemplate: "Streaming 149".notyfiLocalized,
                amount: 149,
                currencyCode: "NOK",
                transactionKind: .expense,
                category: .entertainment,
                merchant: "Netflix",
                note: "",
                frequency: .monthly,
                interval: 1,
                startsAt: nextBillDate,
                nextOccurrenceAt: nextBillDate,
                endsAt: nil,
                isActive: true,
                autopost: true,
                lastGeneratedAt: nil,
                createdAt: now,
                updatedAt: now
            )
        ]
    }
}
