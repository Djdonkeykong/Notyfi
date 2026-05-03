import RevenueCat
import StoreKit
import SwiftUI
import UIKit

struct AppRootView: View {
    @ObservedObject var store: ExpenseJournalStore
    @StateObject private var authManager = AuthManager()
    @StateObject private var languageManager: LanguageManager
    @StateObject private var cloudSyncManager: CloudSyncManager

    @Environment(\.requestReview) private var requestReview

    @AppStorage("notyfi.onboarding.complete") private var hasCompletedOnboarding = false
    @AppStorage(NotyfiAppearanceMode.storageKey) private var appearanceModeRawValue = NotyfiAppearanceMode.system.rawValue
    @AppStorage("notyfi.review.promptedAtCount") private var reviewPromptedAtCount = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var minimumSplashElapsed = false
    @State private var splashDismissed = false
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
        ZStack {
            if !shouldShowSplash {
                if !hasCompletedOnboarding || !authManager.isAuthenticated {
                    OnboardingFlowView(store: store, authManager: authManager)
                        .id(languageManager.refreshID)
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
                                .presentationBackground(NotyfiTheme.brandLight)
                        }
                }
            }

            splashScreen
                .opacity(shouldShowSplash ? 1 : 0)
                .animation(.easeOut(duration: 0.4), value: shouldShowSplash)
                .allowsHitTesting(shouldShowSplash)
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
        .onChange(of: minimumSplashElapsed && authManager.isReady && cloudSyncManager.isReady) { _, ready in
            if ready { splashDismissed = true }
        }
        .onChange(of: store.entries.count) { _, newCount in
            considerRequestingReview(entryCount: newCount)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
        ) { _ in
            Task { await NotificationContentEngine.shared.reschedule(store: store) }
            if authManager.isAuthenticated { Task { await checkSubscriptionStatus() } }
        }
    }

    private var splashScreen: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            Image("LaunchImage")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: horizontalSizeClass == .regular ? 500 : 350)
        }
        .ignoresSafeArea()
    }

    private var shouldShowSplash: Bool {
        !splashDismissed && (!minimumSplashElapsed || !authManager.isReady || !cloudSyncManager.isReady)
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

    private func considerRequestingReview(entryCount: Int) {
        let milestones = [10, 50, 200]
        guard let milestone = milestones.first(where: { $0 > reviewPromptedAtCount && entryCount >= $0 }) else {
            return
        }
        reviewPromptedAtCount = milestone
        requestReview()
    }

    private func checkSubscriptionStatus() async {
        if authManager.supabaseUserEmail?.lowercased() == "appstore@notyfi.app" {
            return
        }
        do {
            let info: CustomerInfo
            if let userID = authManager.supabaseUserID {
                (info, _) = try await Purchases.shared.logIn(userID)
            } else {
                info = try await Purchases.shared.customerInfo()
            }
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
