import SwiftUI
import RevenueCat

@main
struct NotyfiApp: App {
    @StateObject private var store = ExpenseJournalStore()

    init() {
        Purchases.configure(withAPIKey: "test_jOQXQZsoFfUBBxAXuhJtKDCqFiR")
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(store: store)
        }
    }
}
