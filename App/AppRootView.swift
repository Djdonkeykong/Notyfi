import RevenueCat
import SwiftUI
import UIKit

struct AppRootView: View {
    @ObservedObject var store: ExpenseJournalStore
    @StateObject private var authManager = AuthManager()
    @StateObject private var languageManager: LanguageManager
    @StateObject private var cloudSyncManager: CloudSyncManager

    @AppStorage("notyfi.onboarding.complete") private var hasCompletedOnboarding = false
    @AppStorage(NotyfiAppearanceMode.storageKey) private var appearanceModeRawValue = NotyfiAppearanceMode.system.rawValue
    @State private var minimumSplashElapsed = false
    @State private var showPaywall = false

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
            if shouldShowSplash {
                splashScreen
            } else if !hasCompletedOnboarding {
                OnboardingFlowView(store: store, authManager: authManager)
                    .id(languageManager.refreshID)
            } else if !authManager.isAuthenticated {
                OnboardingFlowView(store: store, authManager: authManager)
            } else {
                HomeView(store: store, authManager: authManager)
                    .id(languageManager.refreshID)
                    .task(id: authManager.isAuthenticated) {
                        guard authManager.isAuthenticated else {
                            showPaywall = false
                            return
                        }
                        await checkSubscriptionStatus()
                    }
                    .fullScreenCover(isPresented: $showPaywall) {
                        ProPaywallView(onDismiss: { showPaywall = false })
                            .interactiveDismissDisabled()
                    }
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
        .task {
            guard !minimumSplashElapsed else { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
            minimumSplashElapsed = true
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
        ) { _ in
            Task { await NotificationContentEngine.shared.reschedule(store: store) }
        }
    }

    private var splashScreen: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            Image("LaunchImage")
                .resizable()
                .scaledToFit()
                .frame(width: 350, height: 120)
        }
        .ignoresSafeArea()
    }

    private var shouldShowSplash: Bool {
        !minimumSplashElapsed
            || !authManager.isReady
    }

    private var appearanceMode: NotyfiAppearanceMode {
        NotyfiAppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    private var syncTaskID: String {
        "\(authManager.isReady)-\(authManager.isAuthenticated)"
    }

    private func syncOnboardingWithAuthState() {
        // Safety net: if auth fires while a bootstrap is pending (i.e. the user
        // just finished onboarding and the isComplete flag hasn't propagated yet),
        // mark onboarding complete here too. OnboardingFlowView.onChange handles
        // this in the common case; this catches any edge case where the view
        // observer fires slightly late.
        //
        // We intentionally do NOT auto-complete for users without a pending
        // bootstrap — that path goes through OnboardingFlowView.onChange which
        // does a Supabase check to distinguish returning users from bypass cases.
        guard authManager.isReady,
              authManager.isAuthenticated,
              !hasCompletedOnboarding,
              PendingOnboardingBootstrap.shouldBootstrap() else { return }
        hasCompletedOnboarding = true
    }

    private func checkSubscriptionStatus() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            if info.entitlements["Notyfi Pro"]?.isActive != true {
                showPaywall = true
            }
        } catch {
            // RevenueCat unavailable — show paywall so unverified users are gated.
            showPaywall = true
        }
    }
}

#Preview {
    AppRootView(store: ExpenseJournalStore(previewMode: true))
}
