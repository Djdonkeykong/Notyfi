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

    // Content slide — fractional: 0 = on screen, -1 = off left, +1 = off right
    @State private var incomingOffset: CGFloat = 0
    @State private var outgoingOffset: CGFloat = 0

    // Chrome slide — only moves on boundary transitions (welcome<->step1, widget<->auth)
    @State private var chromeVisible: Bool = false
    @State private var chromeOffset: CGFloat = 0

    // Captured from GeometryReader so overlays can use it
    @State private var viewWidth: CGFloat = 390

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

    // Whether a given step shows chrome (back + progress + continue)
    private func hasChrome(_ step: OnboardingStep) -> Bool {
        switch step {
        case .welcome, .auth: return false
        default: return true
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                NotyfiTheme.brandLight.ignoresSafeArea()

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
            .onAppear { viewWidth = geo.size.width }
        }
        .overlay(alignment: .top) {
            if chromeVisible {
                topChrome
                    .offset(x: chromeOffset * viewWidth)
            }
        }
        .overlay(alignment: .bottom) {
            if chromeVisible {
                bottomChrome
                    .offset(x: chromeOffset * viewWidth)
            }
        }
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
        let wasChrome = hasChrome(currentStep)
        let willBeChrome = hasChrome(step)

        stepHistory.append(currentStep)
        outgoingStep = currentStep
        currentStep = step
        isGoingBack = false
        outgoingOffset = 0
        incomingOffset = 1

        // Prepare chrome for this transition
        if !wasChrome && willBeChrome {
            // Welcome -> HowItWorks: chrome slides in from the right with the content
            chromeVisible = true
            chromeOffset = 1
        } else if wasChrome && !willBeChrome {
            // Widget -> Auth: chrome slides out to the left with the content
            // chromeVisible stays true so it can animate out
            chromeOffset = 0
        }
        // Middle steps: chromeVisible/chromeOffset unchanged (stays locked in place)

        withAnimation(.spring(response: 0.38, dampingFraction: 0.96)) {
            outgoingOffset = -1
            incomingOffset = 0
            if !wasChrome && willBeChrome {
                chromeOffset = 0   // slides to center
            } else if wasChrome && !willBeChrome {
                chromeOffset = -1  // exits left
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            outgoingStep = nil
            chromeVisible = willBeChrome
            chromeOffset = 0
        }
    }

    private func goBack() {
        guard let prev = stepHistory.popLast() else { return }
        let wasChrome = hasChrome(currentStep)
        let willBeChrome = hasChrome(prev)

        outgoingStep = currentStep
        currentStep = prev
        isGoingBack = true
        outgoingOffset = 0
        incomingOffset = -1

        // Prepare chrome for this transition
        if !wasChrome && willBeChrome {
            // Auth -> Widget (back): chrome slides in from the left with the content
            chromeVisible = true
            chromeOffset = -1
        } else if wasChrome && !willBeChrome {
            // HowItWorks -> Welcome (back): chrome slides out to the right with the content
            // chromeVisible stays true so it can animate out
            chromeOffset = 0
        }
        // Middle steps: chrome stays locked in place

        withAnimation(.spring(response: 0.38, dampingFraction: 0.96)) {
            outgoingOffset = 1
            incomingOffset = 0
            if !wasChrome && willBeChrome {
                chromeOffset = 0   // slides to center from left
            } else if wasChrome && !willBeChrome {
                chromeOffset = 1   // exits right
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            outgoingStep = nil
            chromeVisible = willBeChrome
            chromeOffset = 0
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
