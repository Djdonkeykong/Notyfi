import SwiftUI

struct AppRootView: View {
    @ObservedObject var store: ExpenseJournalStore
    @AppStorage(NotyfiAppearanceMode.storageKey) private var appearanceModeRawValue = NotyfiAppearanceMode.system.rawValue

    var body: some View {
        HomeView(store: store)
            .preferredColorScheme(appearanceMode.colorScheme)
    }

    private var appearanceMode: NotyfiAppearanceMode {
        NotyfiAppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }
}

#Preview {
    AppRootView(store: ExpenseJournalStore(previewMode: true))
}

