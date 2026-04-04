import Combine
import Foundation

struct DraftComposerFeedback {
    var primaryText: String
    var secondaryText: String?
    var primaryColorName: PrimaryColorName

    enum PrimaryColorName {
        case neutral
        case accent
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var selectedDate: Date
    @Published var composerText = ""
    @Published var journalText = ""
    @Published var isDatePickerPresented = false
    @Published var isSettingsPresented = false
    @Published private(set) var displayedEntries: [ExpenseEntry] = []
    @Published private(set) var insight: JournalInsight = .empty

    let currencyCode = "NOK"

    private let store: ExpenseJournalStore
    private let calendar: Calendar
    private var composerDraftsByDay: [Date: String] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(
        store: ExpenseJournalStore,
        calendar: Calendar = .current
    ) {
        self.selectedDate = calendar.startOfDay(for: Date())
        self.store = store
        self.calendar = calendar

        Publishers.CombineLatest(store.$entries, $selectedDate)
            .sink { [weak self] entries, date in
                self?.recompute(entries: entries, selectedDate: date)
            }
            .store(in: &cancellables)
    }

    var entryCountText: String {
        let count = displayedEntries.count
        return count == 1 ? "1 note" : "\(count) notes"
    }

    var hasEntries: Bool {
        !displayedEntries.isEmpty
    }

    var draftFeedback: DraftComposerFeedback? {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return DraftComposerFeedback(
            primaryText: "Checking",
            secondaryText: nil,
            primaryColorName: .neutral
        )
    }

    var hasFocusedJournalText: Bool {
        !displayedEntries.isEmpty || !composerText.isEmpty
    }

    func addEntry() {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        store.addEntry(from: trimmed, on: selectedDate, currencyCode: currencyCode)
        composerText = ""
        composerDraftsByDay[dayKey(for: selectedDate)] = ""
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
        let entryLineCount = max(lines.count - 1, 0)
        let currentEntries = displayedEntries
        let preservedEntryCount = min(currentEntries.count, entryLineCount)

        if preservedEntryCount > 0 {
            for index in 0..<preservedEntryCount where currentEntries[index].rawText != lines[index] {
                updateEntryText(currentEntries[index], rawText: lines[index])
            }
        }

        if currentEntries.count > entryLineCount {
            currentEntries[entryLineCount...].forEach { entry in
                store.removeEntry(id: entry.id)
            }
        } else if entryLineCount > currentEntries.count {
            appendJournalLines(
                Array(lines[currentEntries.count..<entryLineCount]),
                after: currentEntries.last
            )
        }

        let nextComposerText = lines.last ?? ""
        if composerText != nextComposerText {
            composerText = nextComposerText
        }

        composerDraftsByDay[dayKey(for: selectedDate)] = composerText

        if journalText != normalized {
            journalText = normalized
        }
    }

    func updateComposerText(_ rawText: String) {
        let normalized = rawText.replacingOccurrences(of: "\r\n", with: "\n")

        if composerText != normalized {
            composerText = normalized
        }

        composerDraftsByDay[dayKey(for: selectedDate)] = composerText
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

        store.addEntry(
            from: normalizedLeadingText,
            on: selectedDate,
            currencyCode: currencyCode
        )

        composerText = normalizedTrailingText
        composerDraftsByDay[dayKey(for: selectedDate)] = composerText

        return JournalEditorFocusRequest(
            target: .composer(dayKey(for: selectedDate)),
            cursorPlacement: .start
        )
    }

    func mergeComposerBackward() -> JournalEditorFocusRequest? {
        guard let previousEntry = displayedEntries.last else {
            return nil
        }

        let insertionOffset = previousEntry.rawText.utf16.count
        let mergedText = previousEntry.rawText + composerText
        store.updateEntry(
            pendingTextEntry(previousEntry, rawText: mergedText),
            shouldReparseRawText: true
        )
        composerText = ""
        composerDraftsByDay[dayKey(for: selectedDate)] = ""

        return JournalEditorFocusRequest(
            target: .entry(previousEntry.id),
            cursorPlacement: .offset(insertionOffset)
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
        leadingText: String,
        trailingText: String
    ) -> JournalEditorFocusRequest? {
        let normalizedLeadingText = leadingText.replacingOccurrences(of: "\r\n", with: "\n")
        let normalizedTrailingText = trailingText.replacingOccurrences(of: "\r\n", with: "\n")

        store.updateEntry(
            pendingTextEntry(entry, rawText: normalizedLeadingText),
            shouldReparseRawText: true
        )

        let insertedEntryID = store.insertEntry(
            after: entry,
            rawText: normalizedTrailingText,
            on: entry.date,
            currencyCode: entry.currencyCode
        )

        return JournalEditorFocusRequest(
            target: .entry(insertedEntryID),
            cursorPlacement: .start
        )
    }

    func mergeEntryBackward(_ entry: ExpenseEntry) -> JournalEditorFocusRequest? {
        guard let currentIndex = displayedEntries.firstIndex(where: { $0.id == entry.id }) else {
            return nil
        }

        guard currentIndex > 0 else {
            guard entry.rawText.isEmpty else {
                return JournalEditorFocusRequest(
                    target: .entry(entry.id),
                    cursorPlacement: .start
                )
            }

            let nextEntry = displayedEntries.dropFirst().first
            store.removeEntry(id: entry.id)

            if let nextEntry {
                return JournalEditorFocusRequest(
                    target: .entry(nextEntry.id),
                    cursorPlacement: .start
                )
            }

            composerText = ""
            composerDraftsByDay[dayKey(for: entry.date)] = ""

            return JournalEditorFocusRequest(
                target: .composer(dayKey(for: entry.date)),
                cursorPlacement: .start
            )
        }

        let previousEntry = displayedEntries[currentIndex - 1]
        let insertionOffset = previousEntry.rawText.utf16.count
        let mergedText = previousEntry.rawText + entry.rawText

        store.updateEntry(
            pendingTextEntry(previousEntry, rawText: mergedText),
            shouldReparseRawText: true
        )
        store.removeEntry(id: entry.id)

        return JournalEditorFocusRequest(
            target: .entry(previousEntry.id),
            cursorPlacement: .offset(insertionOffset)
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

    private func recompute(entries: [ExpenseEntry], selectedDate: Date) {
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
    }

    private func appendJournalLines(
        _ lines: [String],
        after trailingEntry: ExpenseEntry?
    ) {
        var currentTrailingEntry = trailingEntry

        for line in lines {
            if let trailingEntry = currentTrailingEntry,
               let insertedEntry = insertEntryAfterReference(
                   trailingEntry,
                   rawText: line,
                   on: selectedDate
               ) {
                currentTrailingEntry = insertedEntry
            } else {
                store.addEntry(
                    from: line,
                    on: selectedDate,
                    currencyCode: currencyCode
                )
                currentTrailingEntry = store.entries(on: selectedDate).max {
                    $0.createdAt < $1.createdAt
                }
            }
        }
    }

    private func insertEntryAfterReference(
        _ referenceEntry: ExpenseEntry,
        rawText: String,
        on date: Date
    ) -> ExpenseEntry? {
        let insertedEntryID = store.insertEntry(
            after: referenceEntry,
            rawText: rawText,
            on: date,
            currencyCode: currencyCode
        )

        return store.entries.first { $0.id == insertedEntryID }
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

    private func pendingTextEntry(_ entry: ExpenseEntry, rawText: String) -> ExpenseEntry {
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        return ExpenseEntry(
            id: entry.id,
            rawText: rawText,
            title: trimmedText.isEmpty ? entry.title : trimmedText,
            amount: 0,
            currencyCode: entry.currencyCode,
            transactionKind: entry.transactionKind,
            category: .uncategorized,
            merchant: nil,
            date: entry.date,
            note: entry.note,
            confidence: .uncertain,
            isAmountEstimated: false,
            createdAt: entry.createdAt
        )
    }

    private func dayKey(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}
