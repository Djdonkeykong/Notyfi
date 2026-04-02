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
    @Published var isDatePickerPresented = false
    @Published var isSettingsPresented = false
    @Published private(set) var displayedEntries: [ExpenseEntry] = []
    @Published private(set) var insight: JournalInsight = .empty

    let currencyCode = "NOK"

    private let store: ExpenseJournalStore
    private let calendar: Calendar
    private let parser: ExpenseParsingServicing
    private var composerDraftsByDay: [Date: String] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(
        store: ExpenseJournalStore,
        calendar: Calendar = .current,
        parser: ExpenseParsingServicing = PlaceholderExpenseParsingService()
    ) {
        self.selectedDate = calendar.startOfDay(for: Date())
        self.store = store
        self.calendar = calendar
        self.parser = parser

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

        let parsed = parser.parse(rawText: trimmed, date: selectedDate, currencyCode: currencyCode)

        if parsed.amount > 0 {
            if parsed.confidence == .certain {
                return DraftComposerFeedback(
                    primaryText: parsed.amount.formattedCurrency(code: parsed.currencyCode),
                    secondaryText: nil,
                    primaryColorName: .accent
                )
            }

            return DraftComposerFeedback(
                primaryText: "Reviewing",
                secondaryText: parsed.amount.formattedCurrency(code: parsed.currencyCode),
                primaryColorName: .neutral
            )
        }

        if trimmed.count < 8 {
            return DraftComposerFeedback(
                primaryText: "Reading",
                secondaryText: nil,
                primaryColorName: .neutral
            )
        }

        return DraftComposerFeedback(
            primaryText: "Parsing",
            secondaryText: nil,
            primaryColorName: .neutral
        )
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
        store.updateEntry(updatedEntry(previousEntry, rawText: mergedText))
        composerText = ""
        composerDraftsByDay[dayKey(for: selectedDate)] = ""

        return JournalEditorFocusRequest(
            target: .entry(previousEntry.id),
            cursorPlacement: .offset(insertionOffset)
        )
    }

    func updateEntryText(_ entry: ExpenseEntry, rawText: String) {
        let normalized = rawText.replacingOccurrences(of: "\r\n", with: "\n")
        store.updateEntry(updatedEntry(entry, rawText: normalized))
    }

    func splitEntryText(
        _ entry: ExpenseEntry,
        leadingText: String,
        trailingText: String
    ) -> JournalEditorFocusRequest? {
        let normalizedLeadingText = leadingText.replacingOccurrences(of: "\r\n", with: "\n")
        let normalizedTrailingText = trailingText.replacingOccurrences(of: "\r\n", with: "\n")

        store.updateEntry(updatedEntry(entry, rawText: normalizedLeadingText))

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

        store.updateEntry(updatedEntry(previousEntry, rawText: mergedText))
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

        let monthEntries = entries.filter {
            calendar.isDate($0.date, equalTo: selectedDate, toGranularity: .month)
        }

        let dayTotal = displayedEntries.reduce(0) { $0 + $1.amount }
        let monthTotal = monthEntries.reduce(0) { $0 + $1.amount }

        let weekEntries = entries.filter {
            calendar.isDate($0.date, equalTo: selectedDate, toGranularity: .weekOfYear)
        }

        let grouped = Dictionary(grouping: weekEntries, by: \.category)
        let topCategory = grouped.max { lhs, rhs in
            lhs.value.reduce(0) { $0 + $1.amount } < rhs.value.reduce(0) { $0 + $1.amount }
        }?.key

        insight = JournalInsight(
            dayTotal: dayTotal,
            monthTotal: monthTotal,
            topCategory: topCategory,
            reviewCount: displayedEntries.filter { $0.confidence.needsReview }.count
        )
    }

    private func sortEntriesChronologically(_ entries: [ExpenseEntry]) -> [ExpenseEntry] {
        entries.sorted { lhs, rhs in
            if calendar.isDate(lhs.date, equalTo: rhs.date, toGranularity: .minute) {
                return lhs.createdAt < rhs.createdAt
            }

            return lhs.date < rhs.date
        }
    }

    private func updatedEntry(_ entry: ExpenseEntry, rawText: String) -> ExpenseEntry {
        let parsed = parser.parse(
            rawText: rawText.trimmingCharacters(in: .whitespacesAndNewlines),
            date: entry.date,
            currencyCode: entry.currencyCode
        )

        return ExpenseEntry(
            id: entry.id,
            rawText: rawText,
            title: parsed.title,
            amount: parsed.amount,
            currencyCode: parsed.currencyCode,
            category: parsed.category,
            merchant: parsed.merchant,
            date: entry.date,
            note: entry.note,
            confidence: parsed.confidence,
            createdAt: entry.createdAt
        )
    }

    private func dayKey(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}
