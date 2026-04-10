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
        ZStack {
            Color(red: 0.0, green: 0.0, blue: 0.996)
                .ignoresSafeArea()
            Image("LaunchScreenLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 260, height: 260)
        }
    }

    private var appearanceMode: NotyfiAppearanceMode {
        NotyfiAppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }
}

#Preview {
    AppRootView(store: ExpenseJournalStore(previewMode: true))
}
