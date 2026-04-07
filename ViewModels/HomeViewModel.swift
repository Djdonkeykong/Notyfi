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

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var selectedDate: Date
    @Published var composerText = ""
    @Published var journalText = ""
    @Published var isDatePickerPresented = false
    @Published var isSettingsPresented = false
    @Published var isStatsPresented = false
    @Published private(set) var displayedEntries: [ExpenseEntry] = []
    @Published private(set) var insight: JournalInsight = .empty
    @Published private(set) var budgetInsight: BudgetInsight = .empty

    let currencyCode = "NOK"

    private let store: ExpenseJournalStore
    private let calendar: Calendar
    private let draftPreviewDelayNanoseconds: UInt64 = 1_800_000_000
    private var composerDraftsByDay: [Date: String] = [:]
    @Published private var composerPreviewDraft: ParsedExpenseDraft?
    private var composerPreviewTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(
        store: ExpenseJournalStore,
        calendar: Calendar = .current
    ) {
        self.selectedDate = calendar.startOfDay(for: Date())
        self.store = store
        self.calendar = calendar

        Publishers.CombineLatest3(store.$entries, $selectedDate, store.$budgetPlan)
            .sink { [weak self] entries, date, budgetPlan in
                self?.recompute(
                    entries: entries,
                    selectedDate: date,
                    budgetPlan: budgetPlan
                )
            }
            .store(in: &cancellables)
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

            return DraftComposerFeedback(
                primaryText: primaryText,
                secondaryText: categoryText,
                primaryColorName: primaryColorName
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
        store.addEntry(from: trimmed, on: selectedDate, currencyCode: currencyCode)
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

    func updateJournalText(_ rawText: String) {
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

        let nextComposerText = hasComposerLine ? lines.last ?? "" : ""
        if composerText != nextComposerText {
            composerText = nextComposerText
        }

        composerDraftsByDay[dayKey(for: selectedDate)] = composerText

        if journalText != normalized {
            journalText = normalized
        }

        scheduleComposerPreviewParse()
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
            on: selectedDate,
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

        store.insertEntry(
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

    func suggestedMonthlyBudgetAmount() -> Double? {
        budgetInsight.suggestedMonthlyBudget
    }

    private func recompute(entries: [ExpenseEntry], selectedDate: Date, budgetPlan: BudgetPlan) {
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

        let dayExpenseTotal = displayedEntries
            .filter { $0.transactionKind == .expense }
            .reduce(0) { $0 + $1.amount }
        let dayIncomeTotal = displayedEntries
            .filter { $0.transactionKind == .income }
            .reduce(0) { $0 + $1.amount }
        let dayNetTotal = dayIncomeTotal - dayExpenseTotal

        let monthExpenseEntries = monthEntries.filter { $0.transactionKind == .expense }
        let monthExpenseTotal = monthExpenseEntries.reduce(0) { $0 + $1.amount }
        let monthIncomeTotal = monthEntries
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
            reviewCount: monthEntries.filter { $0.confidence.needsReview }.count,
            monthEntryCount: monthEntries.count,
            monthAveragePerEntry: monthAveragePerEntry,
            topCategoryShare: topCategoryShare,
            categoryBreakdown: categoryBreakdown
        )

        budgetInsight = makeBudgetInsight(
            for: selectedDate,
            monthExpenseEntries: monthExpenseEntries,
            monthExpenseTotal: monthExpenseTotal,
            monthIncomeTotal: monthIncomeTotal,
            budgetPlan: budgetPlan
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
                let updatedEntry = pendingTextEntry(entry, rawText: rawText)
                store.updateEntry(updatedEntry, shouldReparseRawText: true)
                previousResolvedEntry = updatedEntry
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
                    on: date,
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
            if calendar.isDate(lhs.date, equalTo: rhs.date, toGranularity: .minute) {
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
        budgetPlan: BudgetPlan
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
        var categories = ExpenseCategory.allCases.filter { $0 != .uncategorized }

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
            createdAt: entry.createdAt
        )
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
                return
            }

            guard !Task.isCancelled, let self else {
                return
            }

            if self.composerText.trimmingCharacters(in: .whitespacesAndNewlines) == previewText {
                self.composerPreviewDraft = parsedDraft
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
