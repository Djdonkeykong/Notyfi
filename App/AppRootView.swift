import SwiftUI

struct AppRootView: View {
    @ObservedObject var store: ExpenseJournalStore

    var body: some View {
        HomeView(store: store)
    }
}

#Preview {
    AppRootView(store: ExpenseJournalStore(previewMode: true))
}

