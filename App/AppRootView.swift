import SwiftUI

struct AppRootView: View {
    @ObservedObject var store: ExpenseJournalStore
    @StateObject private var authManager = AuthManager()

    @AppStorage("notyfi.onboarding.complete") private var hasCompletedOnboarding = false
    @AppStorage(NotyfiAppearanceMode.storageKey) private var appearanceModeRawValue = NotyfiAppearanceMode.system.rawValue

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingFlowView(store: store, authManager: authManager)
            } else if !authManager.isAuthenticated {
                OnboardingAuthView(
                    onBack: { hasCompletedOnboarding = false },
                    authManager: authManager
                )
            } else {
                HomeView(store: store, authManager: authManager)
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
    }

    private var appearanceMode: NotyfiAppearanceMode {
        NotyfiAppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }
}

#Preview {
    AppRootView(store: ExpenseJournalStore(previewMode: true))
}
