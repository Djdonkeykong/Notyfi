import Combine
import Foundation

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
    private var cancellables = Set<AnyCancellable>()

    init(store: ExpenseJournalStore, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar

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

    func addEntry() {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        store.addEntry(from: trimmed, on: selectedDate, currencyCode: currencyCode)
        composerText = ""
    }

    func resetToToday() {
        selectedDate = Date()
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
