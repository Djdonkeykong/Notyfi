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
        .onAppear { syncOnboardingWithAuthState() }
        .onChange(of: authManager.isReady) { _, _ in
            syncOnboardingWithAuthState()
        }
        .onChange(of: authManager.isAuthenticated) { _, _ in
            syncOnboardingWithAuthState()
        }
    }

    private var splashScreen: some View {
        Color(red: 0.949, green: 0.949, blue: 0.976)
            .ignoresSafeArea()
    }

    private var appearanceMode: NotyfiAppearanceMode {
        NotyfiAppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    private func syncOnboardingWithAuthState() {
        guard authManager.isReady, authManager.isAuthenticated, !hasCompletedOnboarding else { return }
        hasCompletedOnboarding = true
    }
}

#Preview {
    AppRootView(store: ExpenseJournalStore(previewMode: true))
}
