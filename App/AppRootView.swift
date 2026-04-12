import SwiftUI

struct AppRootView: View {
    @ObservedObject var store: ExpenseJournalStore
    @StateObject private var authManager = AuthManager()
    @StateObject private var languageManager = LanguageManager()

    @AppStorage("notyfi.onboarding.complete") private var hasCompletedOnboarding = false
    @AppStorage(NotyfiAppearanceMode.storageKey) private var appearanceModeRawValue = NotyfiAppearanceMode.system.rawValue
    @State private var minimumSplashElapsed = false

    var body: some View {
        Group {
            if shouldShowSplash {
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
        .task {
            guard !minimumSplashElapsed else { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
            minimumSplashElapsed = true
        }
    }

    private var splashScreen: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            Image("LaunchImage")
                .resizable()
                .scaledToFit()
                .frame(width: 280, height: 255)
        }
    }

    private var shouldShowSplash: Bool {
        !minimumSplashElapsed || !authManager.isReady
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
