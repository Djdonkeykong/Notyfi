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
    @Published var selectedDate: Date = Date()
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

    func handleComposerChange() {
        let normalized = composerText.replacingOccurrences(of: "\r\n", with: "\n")

        if normalized != composerText {
            composerText = normalized
            return
        }

        guard normalized.contains("\n") else {
            return
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
    }

    func resetToToday() {
        selectedDate = Date()
    }

    func moveSelection(by dayOffset: Int) {
        guard dayOffset != 0 else {
            return
        }

        selectedDate = calendar.date(byAdding: .day, value: dayOffset, to: selectedDate) ?? selectedDate
    }

    func date(forDayOffset dayOffset: Int) -> Date {
        calendar.date(byAdding: .day, value: dayOffset, to: selectedDate) ?? selectedDate
    }

    func entries(for date: Date) -> [ExpenseEntry] {
        store.entries(on: date)
            .sorted { $0.date > $1.date }
    }

    private func recompute(entries: [ExpenseEntry], selectedDate: Date) {
        displayedEntries = entries
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date > $1.date }

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
}
