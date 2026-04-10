import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var store: ExpenseJournalStore
    @ObservedObject var authManager: AuthManager

    @AppStorage("notyfi.onboarding.complete") private var isComplete = false
    @AppStorage(NotyfiCurrency.storageKey) private var currencyRawValue = NotyfiCurrencyPreference.auto.rawValue

    @State private var currentStep: OnboardingStep = .welcome
    @State private var outgoingStep: OnboardingStep? = nil
    @State private var stepHistory: [OnboardingStep] = []
    @State private var budgetAmountText: String = ""
    @State private var isGoingBack: Bool = false
    // Fractional offsets: 0 = on screen, -1 = off left, +1 = off right
    @State private var incomingOffset: CGFloat = 0
    @State private var outgoingOffset: CGFloat = 0

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
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Static — never moves regardless of any transition.
                NotyfiTheme.brandLight.ignoresSafeArea()

                // Outgoing view slides out while the incoming slides in.
                if let outgoing = outgoingStep {
                    stepContent(for: outgoing)
                        .offset(x: outgoingOffset * geo.size.width)
                        .zIndex(isGoingBack ? 1 : 0)
                }

                stepContent(for: currentStep)
                    .offset(x: incomingOffset * geo.size.width)
                    .zIndex(isGoingBack ? 0 : 1)
            }
            .clipped()
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

    // MARK: - Step Content

    @ViewBuilder
    private func stepContent(for step: OnboardingStep) -> some View {
        switch step {
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
        .padding(.bottom, 16)
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
        outgoingStep = currentStep
        currentStep = step
        isGoingBack = false
        outgoingOffset = 0
        incomingOffset = 1     // incoming starts off to the right

        withAnimation(.spring(response: 0.38, dampingFraction: 0.96)) {
            outgoingOffset = -1  // outgoing exits to the left
            incomingOffset = 0   // incoming lands at center
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            outgoingStep = nil
        }
    }

    private func goBack() {
        guard let prev = stepHistory.popLast() else { return }
        outgoingStep = currentStep
        currentStep = prev
        isGoingBack = true
        outgoingOffset = 0
        incomingOffset = -1    // incoming starts off to the left

        withAnimation(.spring(response: 0.38, dampingFraction: 0.96)) {
            outgoingOffset = 1   // outgoing exits to the right
            incomingOffset = 0   // incoming lands at center
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            outgoingStep = nil
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
