import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    enum AppearanceMode: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system:
                return "System".notelyLocalized
            case .light:
                return "Light".notelyLocalized
            case .dark:
                return "Dark".notelyLocalized
            }
        }
    }

    @Published var automaticCurrency = true
    @Published var notificationsEnabled = false
    @Published var gentleReviewMode = true
    @Published var syncEnabled = false
    @Published var appearanceMode: AppearanceMode = .system
    @Published var currencyCode = "NOK"

    private let store: ExpenseJournalStore

    init(store: ExpenseJournalStore) {
        self.store = store
    }

    func clearLog() {
        store.clearAllEntries()
    }
}
