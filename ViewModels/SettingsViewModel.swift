import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    enum AppearanceMode: String, Identifiable {
        case system

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system:
                return "System".notyfiLocalized
            }
        }
    }

    @Published var appearanceMode: AppearanceMode = .system
    @Published var currencyCode = "NOK"

    private let store: ExpenseJournalStore

    init(store: ExpenseJournalStore) {
        self.store = store
    }

    var currencyDisplayName: String {
        switch currencyCode.uppercased() {
        case "NOK":
            return "Norwegian Krone (NOK)".notyfiLocalized
        case "USD":
            return "US Dollar (USD)".notyfiLocalized
        case "EUR":
            return "Euro (EUR)".notyfiLocalized
        default:
            return currencyCode
        }
    }

    var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (version?, build?) where version != build:
            return "\(version) (\(build))"
        case let (version?, _):
            return version
        case let (_, build?):
            return build
        default:
            return "1.0"
        }
    }

    func clearLog() {
        store.clearAllEntries()
    }
}
