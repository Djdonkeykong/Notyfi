import SwiftUI

@main
struct NotyfiApp: App {
    @StateObject private var store = ExpenseJournalStore()

    var body: some Scene {
        WindowGroup {
            AppRootView(store: store)
        }
    }
}
