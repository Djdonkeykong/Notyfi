import SwiftUI

struct AppRootView: View {
    @ObservedObject var store: ExpenseJournalStore
    @StateObject private var authManager = AuthManager()
    @StateObject private var languageManager = LanguageManager()

    @AppStorage("notyfi.onboarding.complete") private var hasCompletedOnboarding = false
    @AppStorage(NotyfiAppearanceMode.storageKey) private var appearanceModeRawValue = NotyfiAppearanceMode.system.rawValue

    var body: some View {
        Group {
            if !authManager.isReady {
                splashScreen
            } else if !hasCompletedOnboarding {
                OnboardingFlowView(store: store, authManager: authManager)
                    .id(languageManager.refreshID)
            } else if !authManager.isAuthenticated {
                OnboardingSignInView(authManager: authManager)
            } else {
                HomeView(store: store, authManager: authManager)
            }
        }
        .environmentObject(languageManager)
        .preferredColorScheme(appearanceMode.colorScheme)
    }

    private var splashScreen: some View {
        Color(red: 0.949, green: 0.949, blue: 0.976)
            .ignoresSafeArea()
    }

    private var appearanceMode: NotyfiAppearanceMode {
        NotyfiAppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }
}

#Preview {
    AppRootView(store: ExpenseJournalStore(previewMode: true))
}
