import SwiftUI

struct AppRootView: View {
    @ObservedObject var store: ExpenseJournalStore
    @StateObject private var authManager = AuthManager()
    @StateObject private var languageManager: LanguageManager
    @StateObject private var cloudSyncManager: CloudSyncManager

    @AppStorage("notyfi.onboarding.complete") private var hasCompletedOnboarding = false
    @AppStorage(NotyfiAppearanceMode.storageKey) private var appearanceModeRawValue = NotyfiAppearanceMode.system.rawValue

    init(store: ExpenseJournalStore) {
        self.store = store
        let languageManager = LanguageManager()
        _languageManager = StateObject(wrappedValue: languageManager)
        _cloudSyncManager = StateObject(
            wrappedValue: CloudSyncManager(
                store: store,
                languageManager: languageManager
            )
        )
    }

    var body: some View {
        Group {
            if isLoadingAppState {
                loadingView
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
        .task(id: syncTaskID) {
            await cloudSyncManager.refreshAuthenticationState(
                isReady: authManager.isReady,
                isAuthenticated: authManager.isAuthenticated
            )
        }
    }

    private var loadingView: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            ProgressView()
                .controlSize(.large)
        }
    }

    private var isLoadingAppState: Bool {
        !authManager.isReady
            || (authManager.isAuthenticated && !cloudSyncManager.isReady)
    }

    private var appearanceMode: NotyfiAppearanceMode {
        NotyfiAppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    private var syncTaskID: String {
        "\(authManager.isReady)-\(authManager.isAuthenticated)"
    }

    private func syncOnboardingWithAuthState() {
        guard authManager.isReady, authManager.isAuthenticated, !hasCompletedOnboarding else { return }
        hasCompletedOnboarding = true
    }
}

#Preview {
    AppRootView(store: ExpenseJournalStore(previewMode: true))
}
