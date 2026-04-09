import SwiftUI
import RevenueCat

@main
struct NotyfiApp: App {
    @StateObject private var store = ExpenseJournalStore()

    init() {
        Purchases.configure(withAPIKey: "appl_GngBYbfKxrVpjUFIKMMaGPhkpRr")
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(store: store)
        }
    }
}
