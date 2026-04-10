import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var store: ExpenseJournalStore
    @ObservedObject var authManager: AuthManager

    @AppStorage("notyfi.onboarding.complete") private var isComplete = false
    @AppStorage(NotyfiCurrency.storageKey) private var currencyRawValue = NotyfiCurrencyPreference.auto.rawValue

    @State private var currentStep: OnboardingStep = .welcome
    @State private var stepHistory: [OnboardingStep] = []
    @State private var budgetAmountText: String = ""
    @State private var isGoingBack: Bool = false

    private var showChrome: Bool {
        switch currentStep {
        case .welcome, .auth: return false
        default: return true
        }
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
        ZStack {
            // Truly static — never participates in any transition.
            NotyfiTheme.brandLight.ignoresSafeArea()

            currentContent
                .id(currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: isGoingBack ? .leading : .trailing),
                    removal: .move(edge: isGoingBack ? .trailing : .leading)
                ))
        }
        .overlay(alignment: .top) {
            if showChrome {
                topChrome
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if showChrome {
                bottomChrome
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showChrome)
        .onChange(of: authManager.isAuthenticated) { _, authenticated in
            if authenticated { isComplete = true }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var currentContent: some View {
        switch currentStep {
        case .welcome:
            OnboardingWelcomeView(
                onGetStarted: { navigate(to: .howItWorks) },
                onSignIn: { navigate(to: .auth) }
            )
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
            OnboardingAuthView(authManager: authManager, onBack: { goBack() })
        }
    }

    // MARK: - Chrome

    private var topChrome: some View {
        HStack(spacing: 12) {
            OnboardingBackButton { goBack() }
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

    // MARK: - Navigation

    private func navigate(to step: OnboardingStep) {
        stepHistory.append(currentStep)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.96)) {
            isGoingBack = false
            currentStep = step
        }
    }

    private func goBack() {
        guard let prev = stepHistory.popLast() else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.96)) {
            isGoingBack = true
            currentStep = prev
        }
    }

    private func handleContinue() {
        switch currentStep {
        case .howItWorks:
            navigate(to: .currency)
        case .currency:
            navigate(to: .budget)
        case .budget:
            let normalized = budgetAmountText
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespaces)
            if let amount = Double(normalized) {
                store.setMonthlySpendingLimit(amount)
            }
            budgetAmountText = ""
            navigate(to: .notifications)
        case .notifications:
            navigate(to: .beDetailed)
        case .beDetailed:
            navigate(to: .inputMethods)
        case .inputMethods:
            navigate(to: .widget)
        case .widget:
            navigate(to: .auth)
        default:
            break
        }
    }
}

enum OnboardingStep: Hashable {
    case welcome
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
