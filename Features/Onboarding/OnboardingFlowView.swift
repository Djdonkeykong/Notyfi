import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var store: ExpenseJournalStore
    @ObservedObject var authManager: AuthManager

    @AppStorage("notyfi.onboarding.complete") private var isComplete = false
    @AppStorage(NotyfiCurrency.storageKey) private var currencyRawValue = NotyfiCurrencyPreference.auto.rawValue

    @State private var path: [OnboardingStep] = []
    @State private var budgetAmountText: String = ""

    private var currentStep: OnboardingStep? { path.last }

    private var showChrome: Bool {
        guard let step = currentStep else { return false }
        return step != .auth
    }

    private var progressStep: Int {
        switch currentStep {
        case .howItWorks: return 1
        case .currency: return 2
        case .budget: return 3
        case .notifications: return 4
        case .beDetailed: return 5
        case .inputMethods: return 6
        case .widget: return 7
        default: return 0
        }
    }

    private var continueTitle: String {
        guard currentStep == .budget else { return "Continue" }
        let normalized = budgetAmountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return Double(normalized) != nil ? "Set Budget" : "Continue"
    }

    private var selectedCurrencyCode: String {
        NotyfiCurrencyPreference(rawValue: currencyRawValue)?.currencyCode
            ?? NotyfiCurrency.deviceCode
    }

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingWelcomeView(
                onGetStarted: { path.append(.howItWorks) },
                onSignIn: { path = [.auth] }
            )
            .navigationDestination(for: OnboardingStep.self) { step in
                destination(for: step)
            }
        }
        // Chrome overlays live outside NavigationStack — they never push or pop.
        // Insertion slides from trailing to match the NavigationStack push direction.
        // Removal fades (only happens when going to auth).
        .overlay(alignment: .top) {
            if showChrome {
                topChrome
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .opacity
                    ))
            }
        }
        .overlay(alignment: .bottom) {
            if showChrome {
                bottomChrome
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.92), value: showChrome)
        .onChange(of: authManager.isAuthenticated) { _, authenticated in
            if authenticated { isComplete = true }
        }
    }

    // MARK: - Floating chrome

    private var topChrome: some View {
        HStack(spacing: 12) {
            OnboardingBackButton { path.removeLast() }
            OnboardingProgressBar(current: progressStep, total: 7)
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .background {
            LinearGradient(
                colors: [NotyfiTheme.brandLight, NotyfiTheme.brandLight.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    private var bottomChrome: some View {
        OnboardingPrimaryButton(title: continueTitle) {
            handleContinue()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 40)
        .background {
            LinearGradient(
                colors: [NotyfiTheme.brandLight.opacity(0), NotyfiTheme.brandLight],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Destinations

    @ViewBuilder
    private func destination(for step: OnboardingStep) -> some View {
        switch step {
        case .howItWorks:
            OnboardingHowItWorksView()
        case .currency:
            OnboardingCurrencyView(currencyRawValue: $currencyRawValue)
        case .budget:
            OnboardingBudgetView(currencyCode: selectedCurrencyCode, amountText: $budgetAmountText)
        case .notifications:
            OnboardingNotificationsView()
        case .beDetailed:
            OnboardingBeDetailedView()
        case .inputMethods:
            OnboardingInputMethodsView()
        case .widget:
            OnboardingWidgetView()
        case .auth:
            OnboardingAuthView(authManager: authManager)
        }
    }

    // MARK: - Actions

    private func handleContinue() {
        switch currentStep {
        case .howItWorks:
            path.append(.currency)
        case .currency:
            path.append(.budget)
        case .budget:
            let normalized = budgetAmountText
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespaces)
            if let amount = Double(normalized) {
                store.setMonthlySpendingLimit(amount)
            }
            budgetAmountText = ""
            path.append(.notifications)
        case .notifications:
            path.append(.beDetailed)
        case .beDetailed:
            path.append(.inputMethods)
        case .inputMethods:
            path.append(.widget)
        case .widget:
            path.append(.auth)
        default:
            break
        }
    }


}

enum OnboardingStep: Hashable {
    case howItWorks
    case currency
    case budget
    case notifications
    case beDetailed
    case inputMethods
    case widget
    case auth
}

#Preview {
    OnboardingFlowView(
        store: ExpenseJournalStore(previewMode: true),
        authManager: AuthManager()
    )
}
