import SwiftUI

@main
struct NotelyApp: App {
    @StateObject private var store = ExpenseJournalStore()

    var body: some Scene {
        WindowGroup {
            AppRootView(store: store)
        }
    }
}

