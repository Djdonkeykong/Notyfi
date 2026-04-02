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
            .receive(on: DispatchQueue.main)
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
    }

    func handleComposerBackspaceOnEmpty() {
        guard composerText.isEmpty, let lastEntry = displayedEntries.last else {
            return
        }

        store.removeEntry(id: lastEntry.id)
        composerText = lastEntry.rawText
    }

    func handleComposerChange() -> Bool {
        let normalized = composerText.replacingOccurrences(of: "\r\n", with: "\n")

        if normalized != composerText {
            composerText = normalized
            return false
        }

        guard normalized.contains("\n") else {
            return false
        }

        let parts = normalized.components(separatedBy: "\n")
        let trailingDraft = parts.last ?? ""
        let completedLines = parts
            .dropLast()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in completedLines {
            store.addEntry(from: line, on: selectedDate, currencyCode: currencyCode)
        }

        composerText = trailingDraft
        return !completedLines.isEmpty && trailingDraft.isEmpty
    }

    func updateEntryText(_ entry: ExpenseEntry, rawText: String) -> Bool {
        let normalized = rawText.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        let currentEntryText = lines.first ?? ""
        let nextDraftText = lines.dropFirst().joined(separator: "\n")

        let parsed = parser.parse(
            rawText: currentEntryText.trimmingCharacters(in: .whitespacesAndNewlines),
            date: entry.date,
            currencyCode: entry.currencyCode
        )

        let updated = ExpenseEntry(
            id: entry.id,
            rawText: parsed.rawText,
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

        store.updateEntry(updated)

        guard lines.count > 1 else {
            return false
        }

        composerText = nextDraftText
        return true
    }

    func resetToToday() {
        setSelectedDate(Date())
    }

    func setSelectedDate(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
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
}
