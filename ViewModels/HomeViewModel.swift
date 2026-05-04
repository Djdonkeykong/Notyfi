import Combine
import Foundation

struct DraftComposerFeedback {
    var primaryText: String
    var secondaryText: String?
    var primaryColorName: PrimaryColorName

    enum PrimaryColorName {
        case neutral
        case accent
        case income
        case expense
    }
}

enum QuickAddAction: String, CaseIterable, Identifiable {
    case expense
    case income
    case transfer        // not yet implemented
    case recurringExpense
    case recurringIncome
    case attachFiles     // not yet implemented

    // transfer and attachFiles hidden until implemented
    static var allCases: [QuickAddAction] { [.expense, .income, .recurringExpense, .recurringIncome] }

    var id: String { rawValue }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var selectedDate: Date
    @Published var composerText = ""
    @Published var journalText = ""
    @Published var isDatePickerPresented = false
    @Published var isSettingsPresented = false
    @Published var isStatsPresented = false
    @Published var isReportsPresented = false
    @Published private(set) var displayedEntries: [ExpenseEntry] = []
    @Published private(set) var insight: JournalInsight = .empty
    @Published private(set) var budgetInsight: BudgetInsight = .empty
    @Published private(set) var currencyCode: String
    @Published private(set) var allEntriesSnapshot: [ExpenseEntry]
    @Published private(set) var trackedCategoriesSnapshot: Set<ExpenseCategory>
    @Published private(set) var recurringTransactionsSnapshot: [RecurringTransaction] = []
    @Published private(set) var hasNewInsightsBadge = false

    @Published private(set) var monthlyInsightsResult: InsightsResult?
    @Published private(set) var monthlyInsightsIsLoading = false

    private let store: ExpenseJournalStore
    private let calendar: Calendar
    private let insightsBadgeGeneratedKey = "notyfi.insights.badge.generated"
    private let insightsBadgeViewedKey = "notyfi.insights.badge.viewed"
    private let draftPreviewDelayNanoseconds: UInt64 = 1_800_000_000
    private var composerDraftsByDay: [Date: String] = [:]
    @Published private var composerPreviewDraft: ParsedExpenseDraft?
    @Published private var composerPreviewFailedText: String?
    private var composerPreviewTask: Task<Void, Never>?
    private let insightsService = SpendingInsightsService()
    private var cancellables = Set<AnyCancellable>()

    init(
        store: ExpenseJournalStore,
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) {
        self.selectedDate = calendar.startOfDay(for: Date())
        self.store = store
        self.calendar = calendar
        self.currencyCode = NotyfiCurrency.currentCode(defaults: defaults)
        self.allEntriesSnapshot = store.entries
        self.trackedCategoriesSnapshot = store.effectiveTrackedCategories

        let generated = defaults.string(forKey: insightsBadgeGeneratedKey) ?? ""
        let viewed = defaults.string(forKey: insightsBadgeViewedKey) ?? ""
        self.hasNewInsightsBadge = !generated.isEmpty && generated != viewed

        Publishers.CombineLatest4(store.$entries, $selectedDate, store.$budgetPlan, store.$effectiveTrackedCategories)
            .sink { [weak self] entries, date, budgetPlan, trackedCategories in
                guard let self else { return }
                self.allEntriesSnapshot = entries
                self.recompute(
                    entries: entries,
                    selectedDate: date,
                    budgetPlan: budgetPlan,
                    trackedCategories: trackedCategories
                )
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .map { _ in NotyfiCurrency.currentCode(defaults: defaults) }
            .removeDuplicates()
            .sink { [weak self] currencyCode in
                self?.currencyCode = currencyCode
            }
            .store(in: &cancellables)

        store.$recurringTransactions
            .sink { [weak self] recurringTransactions in
                self?.recurringTransactionsSnapshot = recurringTransactions
            }
            .store(in: &cancellables)

        store.$effectiveTrackedCategories
            .sink { [weak self] newCategories in
                self?.trackedCategoriesSnapshot = newCategories
            }
            .store(in: &cancellables)
    }

    func markInsightsGenerated(forMonthKey key: String) {
        UserDefaults.standard.set(key, forKey: insightsBadgeGeneratedKey)
        let viewed = UserDefaults.standard.string(forKey: insightsBadgeViewedKey) ?? ""
        hasNewInsightsBadge = key != viewed
    }

    func clearInsightsBadge() {
        let generated = UserDefaults.standard.string(forKey: insightsBadgeGeneratedKey) ?? ""
        UserDefaults.standard.set(generated, forKey: insightsBadgeViewedKey)
        hasNewInsightsBadge = false
    }

    private var isLastDayOfCurrentMonth: Bool {
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return false }
        return !calendar.isDate(today, equalTo: tomorrow, toGranularity: .month)
    }

    var reportMonthDate: Date {
        // Generate on the last day of the current month so the report appears
        // the same day the month closes, not on the 1st of the following month.
        if isLastDayOfCurrentMonth {
            return Date()
        }
        return calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    }

    var lastCompletedMonthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = NotyfiLocale.current()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: reportMonthDate)
    }

    func generateMonthlyInsightsIfNeeded() {
        guard !monthlyInsightsIsLoading, monthlyInsightsResult == nil else { return }
        let month = reportMonthDate
        let key = monthlyInsightsCacheKey(for: month)
        if let cached = loadCachedMonthlyInsights(key: key) {
            monthlyInsightsResult = cached
            return
        }
        // Only call the API on the last day of the month — insights are a
        // month-end summary, not something that should generate mid-month.
        guard isLastDayOfCurrentMonth else { return }
        Task { await generateMonthlyInsights() }
    }

    private func generateMonthlyInsights() async {
        let month = reportMonthDate
        let key = monthlyInsightsCacheKey(for: month)

        if let cached = loadCachedMonthlyInsights(key: key) {
            monthlyInsightsResult = cached
            // Badge state was already set correctly in init() from UserDefaults.
            // Re-evaluating here would race with clearInsightsBadge() and corrupt viewed.
            return
        }

        let entries = allEntriesSnapshot.filter {
            $0.currencyCode.caseInsensitiveCompare(currencyCode) == .orderedSame
        }
        let monthExpenses = entries.filter {
            $0.transactionKind == .expense
                && calendar.isDate($0.date, equalTo: month, toGranularity: .month)
        }
        let expenseTotal = monthExpenses.reduce(0) { $0 + $1.amount }
        guard expenseTotal > 0 else { return }

        let categoryTotals = Dictionary(grouping: monthExpenses) { $0.category }
            .filter { $0.key != .uncategorized }
            .map { category, items in
                SpendingInsightsService.CategoryTotal(
                    category: category.rawValue,
                    total: items.reduce(0) { $0 + $1.amount },
                    entryCount: items.count
                )
            }
            .sorted { $0.total > $1.total }
        guard !categoryTotals.isEmpty else { return }

        let incomeTotal = entries.filter {
            $0.transactionKind == .income
                && calendar.isDate($0.date, equalTo: month, toGranularity: .month)
        }.reduce(0) { $0 + $1.amount }

        let prevMonth = calendar.date(byAdding: .month, value: -1, to: month) ?? month
        let prevExpenseTotal = entries.filter {
            $0.transactionKind == .expense
                && calendar.isDate($0.date, equalTo: prevMonth, toGranularity: .month)
        }.reduce(0) { $0 + $1.amount }

        let topMerchants = Array(
            Dictionary(grouping: monthExpenses) { $0.merchant ?? "" }
                .filter { !$0.key.isEmpty }
                .sorted { $0.value.count > $1.value.count }
                .prefix(5)
                .map(\.key)
        )

        monthlyInsightsIsLoading = true
        do {
            let result = try await insightsService.generate(
                monthLabel: lastCompletedMonthLabel,
                currencyCode: currencyCode,
                expenseTotal: expenseTotal,
                incomeTotal: incomeTotal,
                budgetLimit: budgetPlan.monthlySpendingLimit,
                categoryTotals: categoryTotals,
                previousMonthExpenseTotal: prevExpenseTotal,
                topMerchants: topMerchants
            )
            monthlyInsightsResult = result
            saveCachedMonthlyInsights(result, key: key)
            markInsightsGenerated(forMonthKey: key)
        } catch {
            // Silent fail — will retry next app launch
        }
        monthlyInsightsIsLoading = false
    }

    func monthlyInsightsCacheKey(for date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return "notyfi.insights.v2.\(comps.year ?? 0)-\(comps.month ?? 0).\(currencyCode)"
    }

    private func loadCachedMonthlyInsights(key: String) -> InsightsResult? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(InsightsResult.self, from: data) else {
            return nil
        }
        return decoded
    }

    private func saveCachedMonthlyInsights(_ result: InsightsResult, key: String) {
        guard let data = try? JSONEncoder().encode(result) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    var entryCountText: String {
        String.notyfiNotesCount(displayedEntries.count)
    }

    var hasEntries: Bool {
        !displayedEntries.isEmpty
    }

    var budgetPlan: BudgetPlan {
        store.budgetPlan
    }

    var trackedCategories: Set<ExpenseCategory> {
        trackedCategoriesSnapshot
    }

    var currentStreak: Int {
        let cal = Calendar.current
        let entryDays = Set(store.entries.map { cal.startOfDay(for: $0.date) })
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        var cursor = entryDays.contains(today) ? today : yesterday
        guard entryDays.contains(cursor) else { return 0 }
        var streak = 0
        while entryDays.contains(cursor) {
            streak += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }
        return streak
    }

    var orderedTrackedCategories: [ExpenseCategory] {
        let builtIns = ExpenseCategory.trackableCases.filter { trackedCategories.contains($0) }
        let customs = store.customCategories
            .map(\.asExpenseCategory)
            .filter { trackedCategories.contains($0) }
            .sorted { $0.title < $1.title }
        return builtIns + customs
    }

    func activeRecurringExpenseTransactions(for category: ExpenseCategory) -> [RecurringTransaction] {
        recurringTransactionsSnapshot
            .filter {
                $0.isActive
                    && $0.transactionKind == .expense
                    && $0.category == category
            }
            .sorted { lhs, rhs in
                lhs.nextOccurrenceAt < rhs.nextOccurrenceAt
            }
    }

    var draftFeedback: DraftComposerFeedback? {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let composerPreviewDraft,
           composerPreviewDraft.rawText == trimmed {
            let categoryText: String?
            if composerPreviewDraft.category != .uncategorized {
                categoryText = composerPreviewDraft.category.title
            } else if composerPreviewDraft.transactionKind == .income {
                categoryText = TransactionKind.income.title
            } else {
                categoryText = composerPreviewDraft.merchant
            }

            let primaryText: String
            if composerPreviewDraft.amount > 0 {
                primaryText = Self.signedAmountText(for: composerPreviewDraft)
            } else if composerPreviewDraft.confidence == .review {
                primaryText = "Review".notyfiLocalized
            } else {
                primaryText = "Checking".notyfiLocalized
            }

            let primaryColorName: DraftComposerFeedback.PrimaryColorName
            if composerPreviewDraft.amount > 0 {
                primaryColorName = composerPreviewDraft.transactionKind == .income
                    ? .income
                    : .expense
            } else {
                primaryColorName = .neutral
            }

            let secondaryText: String?
            if composerPreviewDraft.isRecurring {
                let recurrenceText = composerPreviewDraft.recurringFrequency?.title ?? "Recurring".notyfiLocalized

                if let categoryText, !categoryText.isEmpty {
                    secondaryText = "\(categoryText) - \(recurrenceText)"
                } else {
                    secondaryText = recurrenceText
                }
            } else {
                secondaryText = categoryText
            }

            return DraftComposerFeedback(
                primaryText: primaryText,
                secondaryText: secondaryText,
                primaryColorName: primaryColorName
            )
        }

        if composerPreviewFailedText == trimmed {
            return DraftComposerFeedback(
                primaryText: "Offline".notyfiLocalized,
                secondaryText: nil,
                primaryColorName: .neutral
            )
        }

        return DraftComposerFeedback(
            primaryText: "Checking".notyfiLocalized,
            secondaryText: nil,
            primaryColorName: .neutral
        )
    }

    var hasPendingComposerDraft: Bool {
        !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func addEntry() {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        setComposerDraft("")
        store.addEntry(
            from: trimmed,
            on: defaultEntryDate(for: selectedDate),
            currencyCode: currencyCode
        )
    }

    func importEntries(
        from imageData: Data,
        mimeType: String
    ) async throws -> Int {
        let importedEntryIDs = try await store.importEntries(
            from: imageData,
            mimeType: mimeType,
            on: defaultEntryDate(for: selectedDate),
            currencyCode: currencyCode
        )

        return importedEntryIDs.count
    }

    func createManualEntryDraft(for action: QuickAddAction) -> ExpenseEntry {
        let date = defaultEntryDate(for: selectedDate)
        let entry: ExpenseEntry

        switch action {
        case .expense:
            entry = ExpenseEntry(
                rawText: "",
                title: "",
                amount: 0,
                currencyCode: currencyCode,
                transactionKind: .expense,
                category: .uncategorized,
                merchant: nil,
                date: date,
                note: "",
                confidence: .certain,
                isAmountEstimated: false,
                createdAt: Date()
            )
        case .income:
            entry = ExpenseEntry(
                rawText: "",
                title: "",
                amount: 0,
                currencyCode: currencyCode,
                transactionKind: .income,
                category: .uncategorized,
                merchant: nil,
                date: date,
                note: "",
                confidence: .certain,
                isAmountEstimated: false,
                createdAt: Date()
            )
        case .transfer:
            entry = ExpenseEntry(
                rawText: "",
                title: "",
                amount: 0,
                currencyCode: currencyCode,
                transactionKind: .expense,
                category: .uncategorized,
                merchant: nil,
                date: date,
                note: "Move between accounts. Adjust type if needed.".notyfiLocalized,
                confidence: .certain,
                isAmountEstimated: false,
                createdAt: Date()
            )
        case .recurringExpense, .recurringIncome:
            fatalError("Recurring quick add is handled by the recurring editor flow.")
        case .attachFiles:
            fatalError("Attachment from Files is handled outside manual draft creation.")
        }

        store.addManualEntry(entry)
        return entry
    }

    func focusComposer() -> JournalEditorFocusRequest {
        JournalEditorFocusRequest(
            target: .composer(dayKey(for: selectedDate)),
            cursorPlacement: .end
        )
    }

    func journalDraft(for date: Date) -> String {
        composeJournalText(
            entries: entries(for: date),
            composer: composerDraft(for: date)
        )
    }

    @discardableResult
    func updateJournalText(_ rawText: String) -> JournalEditorFocusRequest? {
        let normalized = rawText.replacingOccurrences(of: "\r\n", with: "\n")

        if journalText != normalized {
            journalText = normalized
        }

        let lines = normalized.components(separatedBy: "\n")
        let currentEntries = displayedEntries
        let hasComposerLine = normalized.hasSuffix("\n") || lines.count > currentEntries.count
        let entryLineCount = hasComposerLine ? max(lines.count - 1, 0) : lines.count
        let entryLines = Array(lines.prefix(entryLineCount))

        reconcileEntries(
            currentEntries: currentEntries,
            with: entryLines,
            on: selectedDate
        )

        // When an entry is auto-deleted (text erased to empty), move the cursor
        // to end of the entry above rather than leaving it at the start of the
        // entry that moved into its place.
        let focusRequest = cursorFocusAfterDeletion(previousEntries: currentEntries)

        let nextComposerText = hasComposerLine ? lines.last ?? "" : ""
        if composerText != nextComposerText {
            composerText = nextComposerText
        }

        composerDraftsByDay[dayKey(for: selectedDate)] = composerText

        scheduleComposerPreviewParse()

        return focusRequest
    }

    private func cursorFocusAfterDeletion(
        previousEntries: [ExpenseEntry]
    ) -> JournalEditorFocusRequest? {
        guard displayedEntries.count < previousEntries.count else {
            return nil
        }

        let survivingIDs = Set(displayedEntries.map(\.id))
        guard let firstDeletedIndex = previousEntries.firstIndex(where: { !survivingIDs.contains($0.id) }),
              firstDeletedIndex > 0
        else {
            return nil
        }

        let previousEntryID = previousEntries[firstDeletedIndex - 1].id
        guard let newLineIndex = displayedEntries.firstIndex(where: { $0.id == previousEntryID }),
              let currentPreviousEntry = displayedEntries.first(where: { $0.id == previousEntryID })
        else {
            return nil
        }

        let offset = absoluteOffset(
            lineIndex: newLineIndex,
            column: currentPreviousEntry.rawText.utf16.count,
            entryLines: displayedEntries.map(\.rawText)
        )

        return journalFocusRequest(absoluteOffset: offset)
    }

    func handleReturn(
        at lineIndex: Int,
        leadingText: String,
        trailingText: String
    ) -> JournalEditorFocusRequest? {
        if lineIndex < displayedEntries.count {
            return splitEntryText(
                displayedEntries[lineIndex],
                lineIndex: lineIndex,
                leadingText: leadingText,
                trailingText: trailingText
            )
        }

        return splitComposerText(
            leadingText: leadingText,
            trailingText: trailingText
        )
    }

    func handleBackspaceAtLineStart(
        at lineIndex: Int
    ) -> JournalEditorFocusRequest? {
        if lineIndex < displayedEntries.count {
            return mergeEntryBackward(displayedEntries[lineIndex])
        }

        return mergeComposerBackward()
    }

    func composerDraft(for date: Date) -> String {
        let key = dayKey(for: date)

        if calendar.isDate(key, inSameDayAs: selectedDate) {
            return composerText
        }

        return composerDraftsByDay[key] ?? ""
    }

    func splitComposerText(
        leadingText: String,
        trailingText: String
    ) -> JournalEditorFocusRequest? {
        let normalizedLeadingText = leadingText.replacingOccurrences(of: "\r\n", with: "\n")
        let normalizedTrailingText = trailingText.replacingOccurrences(of: "\r\n", with: "\n")
        let nextEntryLines = displayedEntries.map(\.rawText) + [normalizedLeadingText]

        setComposerDraft(normalizedTrailingText)
        store.addEntry(
            from: normalizedLeadingText,
            on: defaultEntryDate(for: selectedDate),
            currencyCode: currencyCode
        )

        return journalFocusRequest(
            absoluteOffset: absoluteOffsetForLineStart(
                nextEntryLines.count,
                entryLines: nextEntryLines
            )
        )
    }

    func mergeComposerBackward() -> JournalEditorFocusRequest? {
        guard let previousEntry = displayedEntries.last else {
            return nil
        }

        let insertionOffset = previousEntry.rawText.utf16.count
        let mergedText = previousEntry.rawText + composerText
        setComposerDraft("")
        store.updateEntry(
            pendingTextEntry(previousEntry, rawText: mergedText),
            shouldReparseRawText: true
        )

        return journalFocusRequest(
            absoluteOffset: absoluteOffset(
                lineIndex: displayedEntries.count - 1,
                column: insertionOffset,
                entryLines: displayedEntries.dropLast().map(\.rawText) + [mergedText]
            )
        )
    }

    func updateEntryText(_ entry: ExpenseEntry, rawText: String) {
        let normalized = rawText.replacingOccurrences(of: "\r\n", with: "\n")
        store.updateEntry(
            pendingTextEntry(entry, rawText: normalized),
            shouldReparseRawText: true
        )
    }

    func splitEntryText(
        _ entry: ExpenseEntry,
        lineIndex: Int,
        leadingText: String,
        trailingText: String
    ) -> JournalEditorFocusRequest? {
        let normalizedLeadingText = leadingText.replacingOccurrences(of: "\r\n", with: "\n")
        let normalizedTrailingText = trailingText.replacingOccurrences(of: "\r\n", with: "\n")
        let nextEntryLines = Array(displayedEntries.prefix(lineIndex).map(\.rawText))
            + [normalizedLeadingText, normalizedTrailingText]
            + Array(displayedEntries.dropFirst(lineIndex + 1).map(\.rawText))

        store.updateEntry(
            pendingTextEntry(entry, rawText: normalizedLeadingText),
            shouldReparseRawText: true
        )

        _ = store.insertEntry(
            after: entry,
            rawText: normalizedTrailingText,
            on: entry.date,
            currencyCode: entry.currencyCode
        )

        return journalFocusRequest(
            absoluteOffset: absoluteOffsetForLineStart(
                lineIndex + 1,
                entryLines: nextEntryLines
            )
        )
    }

    func mergeEntryBackward(_ entry: ExpenseEntry) -> JournalEditorFocusRequest? {
        guard let currentIndex = displayedEntries.firstIndex(where: { $0.id == entry.id }) else {
            return nil
        }

        guard currentIndex > 0 else {
            guard entry.rawText.isEmpty else {
                return nil
            }

            store.removeEntry(id: entry.id)

            if displayedEntries.dropFirst().first != nil {
                return journalFocusRequest(
                    absoluteOffset: 0
                )
            }

            composerText = ""
            composerDraftsByDay[dayKey(for: entry.date)] = ""

            return journalFocusRequest(absoluteOffset: 0)
        }

        let previousEntry = displayedEntries[currentIndex - 1]
        let insertionOffset = previousEntry.rawText.utf16.count
        let mergedText = previousEntry.rawText + entry.rawText
        let nextEntryLines = Array(displayedEntries.prefix(currentIndex - 1).map(\.rawText))
            + [mergedText]
            + Array(displayedEntries.dropFirst(currentIndex + 1).map(\.rawText))

        store.updateEntry(
            pendingTextEntry(previousEntry, rawText: mergedText),
            shouldReparseRawText: true
        )
        store.removeEntry(id: entry.id)

        return journalFocusRequest(
            absoluteOffset: absoluteOffset(
                lineIndex: currentIndex - 1,
                column: insertionOffset,
                entryLines: nextEntryLines
            )
        )
    }

    func resetToToday() {
        setSelectedDate(Date())
    }

    func setSelectedDate(_ date: Date) {
        let nextDate = dayKey(for: date)
        let currentDate = dayKey(for: selectedDate)

        composerDraftsByDay[currentDate] = composerText

        selectedDate = nextDate
        composerText = composerDraftsByDay[nextDate] ?? ""
        composerPreviewTask?.cancel()
        composerPreviewTask = nil
        composerPreviewDraft = nil
        composerPreviewFailedText = nil
        scheduleComposerPreviewParse()
    }

    func moveSelection(by dayOffset: Int) {
        guard dayOffset != 0 else {
            return
        }

        let nextDate = calendar.date(byAdding: .day, value: dayOffset, to: selectedDate) ?? selectedDate
        setSelectedDate(nextDate)
    }

    func date(forDayOffset dayOffset: Int) -> Date {
        calendar.date(byAdding: .day, value: dayOffset, to: selectedDate) ?? selectedDate
    }

    func entries(for date: Date) -> [ExpenseEntry] {
        sortEntriesChronologically(store.entries(on: date))
    }

    func setMonthlySpendingLimit(_ amount: Double) {
        store.setMonthlySpendingLimit(amount)
    }

    func setMonthlySavingsTarget(_ amount: Double) {
        store.setMonthlySavingsTarget(amount)
    }

    func setCategoryBudget(_ amount: Double, for category: ExpenseCategory) {
        store.setCategoryBudget(amount, for: category)
    }

    func setTrackedCategories(_ categories: Set<ExpenseCategory>) {
        store.setTrackedCategories(categories)
    }

    func suggestedMonthlyBudgetAmount() -> Double? {
        budgetInsight.suggestedMonthlyBudget
    }

    func recurringDraft(for action: QuickAddAction) -> RecurringTransactionDraft? {
        switch action {
        case .recurringExpense:
            return RecurringTransactionDraft(
                title: "",
                rawTextTemplate: "",
                amountText: "",
                currencyCode: currencyCode,
                transactionKind: .expense,
                category: .bills,
                startsAt: defaultEntryDate(for: selectedDate)
            )
        case .recurringIncome:
            return RecurringTransactionDraft(
                title: "",
                rawTextTemplate: "",
                amountText: "",
                currencyCode: currencyCode,
                transactionKind: .income,
                category: .uncategorized,
                startsAt: defaultEntryDate(for: selectedDate)
            )
        default:
            return nil
        }
    }

    private func recompute(
        entries: [ExpenseEntry],
        selectedDate: Date,
        budgetPlan: BudgetPlan,
        trackedCategories: Set<ExpenseCategory>
    ) {
        displayedEntries = sortEntriesChronologically(
            entries.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
        )

        let nextJournalText = composeJournalText(
            entries: displayedEntries,
            composer: composerText
        )

        if journalText != nextJournalText {
            journalText = nextJournalText
        }

        let monthEntries = entries.filter {
            calendar.isDate($0.date, equalTo: selectedDate, toGranularity: .month)
        }
        let selectedCurrencyEntries = monthEntries.filter {
            $0.currencyCode.caseInsensitiveCompare(currencyCode) == .orderedSame
        }
        let selectedCurrencyDisplayedEntries = displayedEntries.filter {
            $0.currencyCode.caseInsensitiveCompare(currencyCode) == .orderedSame
        }

        let dayExpenseTotal = selectedCurrencyDisplayedEntries
            .filter { $0.transactionKind == .expense }
            .reduce(0) { $0 + $1.amount }
        let dayIncomeTotal = selectedCurrencyDisplayedEntries
            .filter { $0.transactionKind == .income }
            .reduce(0) { $0 + $1.amount }
        let dayNetTotal = dayIncomeTotal - dayExpenseTotal

        let monthExpenseEntries = selectedCurrencyEntries.filter { $0.transactionKind == .expense }
        let monthExpenseTotal = monthExpenseEntries.reduce(0) { $0 + $1.amount }
        let monthIncomeTotal = selectedCurrencyEntries
            .filter { $0.transactionKind == .income }
            .reduce(0) { $0 + $1.amount }
        let monthNetTotal = monthIncomeTotal - monthExpenseTotal
        let monthAveragePerEntry = monthExpenseEntries.isEmpty
            ? 0
            : monthExpenseTotal / Double(monthExpenseEntries.count)
        let categoryBreakdown = makeCategoryBreakdown(
            from: monthExpenseEntries,
            monthExpenseTotal: monthExpenseTotal
        )
        let topCategory = categoryBreakdown.first?.category
        let topCategoryShare = categoryBreakdown.first?.share ?? 0

        insight = JournalInsight(
            dayExpenseTotal: dayExpenseTotal,
            dayIncomeTotal: dayIncomeTotal,
            dayNetTotal: dayNetTotal,
            monthExpenseTotal: monthExpenseTotal,
            monthIncomeTotal: monthIncomeTotal,
            monthNetTotal: monthNetTotal,
            topCategory: topCategory,
            reviewCount: selectedCurrencyEntries.filter { $0.confidence.needsReview }.count,
            monthEntryCount: selectedCurrencyEntries.count,
            monthAveragePerEntry: monthAveragePerEntry,
            topCategoryShare: topCategoryShare,
            categoryBreakdown: categoryBreakdown
        )

        budgetInsight = makeBudgetInsight(
            for: selectedDate,
            monthExpenseEntries: monthExpenseEntries,
            monthExpenseTotal: monthExpenseTotal,
            monthIncomeTotal: monthIncomeTotal,
            budgetPlan: budgetPlan,
            trackedCategories: trackedCategories
        )
    }

    private func reconcileEntries(
        currentEntries: [ExpenseEntry],
        with nextLines: [String],
        on date: Date
    ) {
        let operations = reconciliationOperations(
            currentEntries: currentEntries,
            nextLines: nextLines
        )

        var previousResolvedEntry: ExpenseEntry?

        for index in operations.indices {
            switch operations[index] {
            case .keep(let entry):
                previousResolvedEntry = store.entries.first { $0.id == entry.id } ?? entry
            case .update(let entry, let rawText):
                if rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    store.removeEntry(id: entry.id)
                } else {
                    let updatedEntry = pendingTextEntry(entry, rawText: rawText)
                    store.updateEntry(updatedEntry, shouldReparseRawText: true)
                    previousResolvedEntry = updatedEntry
                }
            case .delete(let entry):
                store.removeEntry(id: entry.id)
            case .insert(let rawText):
                let nextResolvedEntry = nextSurvivingEntry(
                    after: index,
                    operations: operations
                )

                let insertedEntryID = store.insertEntry(
                    between: previousResolvedEntry,
                    and: nextResolvedEntry,
                    rawText: rawText,
                    on: defaultEntryDate(for: date),
                    currencyCode: currencyCode
                )

                previousResolvedEntry = store.entries.first { $0.id == insertedEntryID }
            }
        }
    }

    private func composeJournalText(
        entries: [ExpenseEntry],
        composer: String
    ) -> String {
        let entryText = entries.map(\.rawText).joined(separator: "\n")

        guard !entryText.isEmpty else {
            return composer
        }

        return "\(entryText)\n\(composer)"
    }

    private func makeCategoryBreakdown(
        from entries: [ExpenseEntry],
        monthExpenseTotal: Double
    ) -> [JournalCategoryBreakdown] {
        guard monthExpenseTotal > 0 else {
            return []
        }

        let groupedEntries = Dictionary(grouping: entries, by: \.category)

        return groupedEntries.map { category, categoryEntries in
            let total = categoryEntries.reduce(0) { $0 + $1.amount }

            return JournalCategoryBreakdown(
                category: category,
                total: total,
                share: total / monthExpenseTotal,
                entryCount: categoryEntries.count
            )
        }
        .sorted { lhs, rhs in
            if lhs.total == rhs.total {
                return lhs.category.title < rhs.category.title
            }

            return lhs.total > rhs.total
        }
    }

    private func sortEntriesChronologically(_ entries: [ExpenseEntry]) -> [ExpenseEntry] {
        entries.sorted { lhs, rhs in
            if calendar.isDate(lhs.date, equalTo: rhs.date, toGranularity: .day) {
                return lhs.createdAt < rhs.createdAt
            }

            return lhs.date < rhs.date
        }
    }

    private func makeBudgetInsight(
        for date: Date,
        monthExpenseEntries: [ExpenseEntry],
        monthExpenseTotal: Double,
        monthIncomeTotal: Double,
        budgetPlan: BudgetPlan,
        trackedCategories: Set<ExpenseCategory>
    ) -> BudgetInsight {
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        let daysElapsed = max(1, min(calendar.component(.day, from: date), daysInMonth))
        let averageDailySpend = monthExpenseTotal / Double(daysElapsed)
        let projectedExpenseTotal = averageDailySpend * Double(daysInMonth)
        let remainingBudget = budgetPlan.monthlySpendingLimit - monthExpenseTotal
        let spendingProgress = budgetPlan.monthlySpendingLimit > 0
            ? min(max(monthExpenseTotal / budgetPlan.monthlySpendingLimit, 0), 1)
            : 0
        let netThisMonth = monthIncomeTotal - monthExpenseTotal
        let remainingSavingsTarget = budgetPlan.monthlySavingsTarget - max(netThisMonth, 0)
        let savingsProgress = budgetPlan.monthlySavingsTarget > 0
            ? min(max(netThisMonth / budgetPlan.monthlySavingsTarget, 0), 1)
            : 0
        let suggestedMonthlyBudget = suggestedBudgetAmount(
            monthExpenseTotal: monthExpenseTotal,
            projectedExpenseTotal: projectedExpenseTotal,
            currentBudget: budgetPlan.monthlySpendingLimit
        )

        let groupedEntries = Dictionary(grouping: monthExpenseEntries, by: \.category)
        let customTracked = store.customCategories
            .map(\.asExpenseCategory)
            .filter { trackedCategories.contains($0) }
            .sorted { $0.title < $1.title }
        var categories = ExpenseCategory.trackableCases.filter { trackedCategories.contains($0) }
            + customTracked

        if groupedEntries[.uncategorized] != nil || budgetPlan.target(for: .uncategorized) > 0 {
            categories.append(.uncategorized)
        }

        let categoryStatuses = categories.map { category in
            let categoryEntries = groupedEntries[category] ?? []
            let spent = categoryEntries.reduce(0) { $0 + $1.amount }

            return BudgetCategoryStatus(
                category: category,
                spent: spent,
                target: budgetPlan.target(for: category),
                share: monthExpenseTotal > 0 ? spent / monthExpenseTotal : 0,
                entryCount: categoryEntries.count
            )
        }
        .sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive && !rhs.isActive
            }

            if lhs.spent == rhs.spent {
                return lhs.category.title < rhs.category.title
            }

            return lhs.spent > rhs.spent
        }

        let status: BudgetInsight.Status
        if !budgetPlan.hasSpendingLimit {
            status = .needsBudget
        } else if remainingBudget < 0 {
            status = .overBudget
        } else if projectedExpenseTotal > budgetPlan.monthlySpendingLimit * 1.05 {
            status = .caution
        } else {
            status = .balanced
        }

        return BudgetInsight(
            plan: budgetPlan,
            status: status,
            spentThisMonth: monthExpenseTotal,
            incomeThisMonth: monthIncomeTotal,
            netThisMonth: netThisMonth,
            averageDailySpend: averageDailySpend,
            projectedExpenseTotal: projectedExpenseTotal,
            remainingBudget: remainingBudget,
            spendingProgress: spendingProgress,
            remainingSavingsTarget: remainingSavingsTarget,
            savingsProgress: savingsProgress,
            daysElapsed: daysElapsed,
            daysInMonth: daysInMonth,
            suggestedMonthlyBudget: suggestedMonthlyBudget,
            categoryStatuses: categoryStatuses
        )
    }

    private func suggestedBudgetAmount(
        monthExpenseTotal: Double,
        projectedExpenseTotal: Double,
        currentBudget: Double
    ) -> Double? {
        guard currentBudget == 0 else {
            return nil
        }

        let baseline = max(monthExpenseTotal, projectedExpenseTotal)
        guard baseline > 0 else {
            return nil
        }

        return roundBudgetAmount(baseline * 1.08)
    }

    private func roundBudgetAmount(_ amount: Double) -> Double {
        guard amount > 0 else {
            return 0
        }

        let step: Double
        switch amount {
        case 0..<2_000:
            step = 100
        case 2_000..<10_000:
            step = 250
        default:
            step = 500
        }

        return ceil(amount / step) * step
    }

    private func pendingTextEntry(_ entry: ExpenseEntry, rawText: String) -> ExpenseEntry {
        return ExpenseEntry(
            id: entry.id,
            rawText: rawText,
            title: entry.title,
            amount: entry.amount,
            currencyCode: entry.currencyCode,
            transactionKind: entry.transactionKind,
            category: entry.category,
            merchant: entry.merchant,
            date: entry.date,
            note: entry.note,
            confidence: entry.confidence,
            isAmountEstimated: entry.isAmountEstimated,
            createdAt: entry.createdAt,
            recurringTransactionID: entry.recurringTransactionID,
            recurrenceInstanceKey: entry.recurrenceInstanceKey
        )
    }

    private func defaultEntryDate(for selectedDay: Date) -> Date {
        let now = Date()

        if calendar.isDate(selectedDay, inSameDayAs: now) {
            return now
        }

        var components = calendar.dateComponents([.year, .month, .day], from: selectedDay)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: now)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        components.nanosecond = timeComponents.nanosecond

        return calendar.date(from: components) ?? selectedDay
    }

    private func dayKey(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func setComposerDraft(_ rawText: String) {
        let normalized = rawText.replacingOccurrences(of: "\r\n", with: "\n")

        if composerText != normalized {
            composerText = normalized
        }

        composerDraftsByDay[dayKey(for: selectedDate)] = normalized

        composerPreviewTask?.cancel()
        composerPreviewTask = nil
        composerPreviewDraft = nil
        composerPreviewFailedText = nil

        if !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            scheduleComposerPreviewParse()
        }
    }

    private func scheduleComposerPreviewParse() {
        composerPreviewTask?.cancel()

        let previewText = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !previewText.isEmpty else {
            composerPreviewTask = nil
            composerPreviewDraft = nil
            composerPreviewFailedText = nil
            return
        }

        let previewDate = selectedDate
        let previewCurrencyCode = currencyCode
        let previewDelayNanoseconds = draftPreviewDelayNanoseconds

        composerPreviewTask = Task { [weak self, store] in
            try? await Task.sleep(nanoseconds: previewDelayNanoseconds)

            guard !Task.isCancelled else {
                return
            }

            guard let parsedDraft = try? await store.previewDraft(
                rawText: previewText,
                on: previewDate,
                currencyCode: previewCurrencyCode
            ) else {
                guard let self else {
                    return
                }

                guard self.composerText.trimmingCharacters(in: .whitespacesAndNewlines) == previewText else {
                    return
                }

                self.composerPreviewFailedText = previewText
                return
            }

            guard !Task.isCancelled, let self else {
                return
            }

            if self.composerText.trimmingCharacters(in: .whitespacesAndNewlines) == previewText {
                self.composerPreviewDraft = parsedDraft
                self.composerPreviewFailedText = nil
                Haptics.lightImpact()
            }
        }
    }

    private static func signedAmountText(for draft: ParsedExpenseDraft) -> String {
        let formattedAmount = draft.amount.formattedCurrency(code: draft.currencyCode)
        let signedAmount = draft.transactionKind == .income
            ? "+\(formattedAmount)"
            : "-\(formattedAmount)"
        return draft.isAmountEstimated ? "\(signedAmount)*" : signedAmount
    }

    private func journalFocusRequest(
        absoluteOffset: Int
    ) -> JournalEditorFocusRequest {
        JournalEditorFocusRequest(
            target: .composer(dayKey(for: selectedDate)),
            cursorPlacement: .offset(absoluteOffset)
        )
    }

    private func absoluteOffsetForLineStart(
        _ lineIndex: Int,
        entryLines: [String]
    ) -> Int {
        absoluteOffset(
            lineIndex: lineIndex,
            column: 0,
            entryLines: entryLines
        )
    }

    private func absoluteOffset(
        lineIndex: Int,
        column: Int,
        entryLines: [String]
    ) -> Int {
        let safeLineIndex = max(lineIndex, 0)
        let prefixLineCount = min(safeLineIndex, entryLines.count)
        let prefixLength = entryLines.prefix(prefixLineCount).reduce(into: 0) { total, line in
            total += line.utf16.count
        }

        return prefixLength + prefixLineCount + max(column, 0)
    }
}

private extension HomeViewModel {
    struct MatchedJournalLine {
        let currentIndex: Int
        let nextIndex: Int
    }

    enum JournalReconciliationOperation {
        case keep(ExpenseEntry)
        case update(ExpenseEntry, rawText: String)
        case delete(ExpenseEntry)
        case insert(rawText: String)
    }

    private func reconciliationOperations(
        currentEntries: [ExpenseEntry],
        nextLines: [String]
    ) -> [JournalReconciliationOperation] {
        let currentLines = currentEntries.map(\.rawText)
        var operations: [JournalReconciliationOperation] = []
        let matches = longestCommonSubsequenceMatches(
            currentLines: currentLines,
            nextLines: nextLines
        )
        var currentBlockStart = 0
        var nextBlockStart = 0

        for match in matches {
            operations.append(
                contentsOf: reconciliationOperationsForBlock(
                    currentEntries: currentEntries,
                    nextLines: nextLines,
                    currentRange: currentBlockStart..<match.currentIndex,
                    nextRange: nextBlockStart..<match.nextIndex
                )
            )
            operations.append(.keep(currentEntries[match.currentIndex]))
            currentBlockStart = match.currentIndex + 1
            nextBlockStart = match.nextIndex + 1
        }

        operations.append(
            contentsOf: reconciliationOperationsForBlock(
                currentEntries: currentEntries,
                nextLines: nextLines,
                currentRange: currentBlockStart..<currentEntries.count,
                nextRange: nextBlockStart..<nextLines.count
            )
        )

        return operations
    }

    private func nextSurvivingEntry(
        after index: Int,
        operations: [JournalReconciliationOperation]
    ) -> ExpenseEntry? {
        guard index + 1 < operations.count else {
            return nil
        }

        for candidate in operations[(index + 1)...] {
            switch candidate {
            case .keep(let entry), .update(let entry, _):
                return store.entries.first { $0.id == entry.id } ?? entry
            case .delete, .insert:
                continue
            }
        }

        return nil
    }

    private func longestCommonSubsequenceMatches(
        currentLines: [String],
        nextLines: [String]
    ) -> [MatchedJournalLine] {
        let rowCount = currentLines.count
        let columnCount = nextLines.count
        var lengths = Array(
            repeating: Array(repeating: 0, count: columnCount + 1),
            count: rowCount + 1
        )

        guard rowCount > 0, columnCount > 0 else {
            return []
        }

        for row in 1...rowCount {
            for column in 1...columnCount {
                if currentLines[row - 1] == nextLines[column - 1] {
                    lengths[row][column] = lengths[row - 1][column - 1] + 1
                } else {
                    lengths[row][column] = max(lengths[row - 1][column], lengths[row][column - 1])
                }
            }
        }

        var matches: [MatchedJournalLine] = []
        var row = rowCount
        var column = columnCount

        while row > 0, column > 0 {
            if currentLines[row - 1] == nextLines[column - 1] {
                matches.append(
                    MatchedJournalLine(
                        currentIndex: row - 1,
                        nextIndex: column - 1
                    )
                )
                row -= 1
                column -= 1
            } else if lengths[row - 1][column] >= lengths[row][column - 1] {
                row -= 1
            } else {
                column -= 1
            }
        }

        return matches.reversed()
    }

    private func reconciliationOperationsForBlock(
        currentEntries: [ExpenseEntry],
        nextLines: [String],
        currentRange: Range<Int>,
        nextRange: Range<Int>
    ) -> [JournalReconciliationOperation] {
        var operations: [JournalReconciliationOperation] = []
        let overlap = min(currentRange.count, nextRange.count)

        for offset in 0..<overlap {
            let currentEntry = currentEntries[currentRange.lowerBound + offset]
            let nextRawText = nextLines[nextRange.lowerBound + offset]
            operations.append(.update(currentEntry, rawText: nextRawText))
        }

        if currentRange.count > overlap {
            for index in (currentRange.lowerBound + overlap)..<currentRange.upperBound {
                operations.append(.delete(currentEntries[index]))
            }
        }

        if nextRange.count > overlap {
            for index in (nextRange.lowerBound + overlap)..<nextRange.upperBound {
                operations.append(.insert(rawText: nextLines[index]))
            }
        }

        return operations
    }
}
