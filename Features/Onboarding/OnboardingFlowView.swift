import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var store: ExpenseJournalStore
    @ObservedObject var authManager: AuthManager

    @AppStorage("notyfi.onboarding.complete") private var isComplete = false
    @AppStorage(NotyfiCurrency.storageKey) private var currencyRawValue = NotyfiCurrencyPreference.auto.rawValue

    @State private var currentStep: OnboardingStep = .welcome
    @State private var stepHistory: [OnboardingStep] = []
    @State private var budgetAmountText: String = ""
    @State private var selectedCategories: Set<ExpenseCategory> = Set(ExpenseCategory.allCases.filter { $0 != .uncategorized })
    @State private var categoryBudgetTexts: [ExpenseCategory: String] = [:]

    // Two persistent rendering slots. The active slot's view is never recreated
    // during a transition, so its scroll position is preserved while it slides out.
    private enum Slot { case a, b }
    @State private var slotA: OnboardingStep = .welcome
    @State private var slotB: OnboardingStep = .welcome
    @State private var slotAOffset: CGFloat = 0
    @State private var slotBOffset: CGFloat = 1   // B starts off-screen right
    @State private var slotAZIndex: Double = 1
    @State private var slotBZIndex: Double = 0
    @State private var activeSlot: Slot = .a

    // Chrome slide — only moves on boundary transitions (welcome<->step1, widget<->auth)
    @State private var chromeVisible: Bool = false
    @State private var chromeOffset: CGFloat = 0

    // Captured from GeometryReader so overlays can use it
    @State private var viewWidth: CGFloat = 390

    private var progressStep: Int {
        switch currentStep {
        case .currency: return 1
        case .budget: return 2
        case .categories: return 3
        case .allocate: return 4
        case .notifications: return 5
        case .beDetailed: return 6
        case .inputMethods: return 7
        case .widget: return 8
        default: return 0
        }
    }

    private var continueTitle: String { "Continue" }

    private var selectedCurrencyCode: String {
        NotyfiCurrencyPreference(rawValue: currencyRawValue)?.currencyCode
            ?? NotyfiCurrency.deviceCode
    }

    // Whether a given step shows chrome (back + progress + continue)
    private func hasChrome(_ step: OnboardingStep) -> Bool {
        switch step {
        case .welcome, .auth, .signIn: return false
        default: return true
        }
    }

    var body: some View {
        ZStack {
            // Screen-wide background outside the clipped ZStack so it fills
            // safe areas on every page — welcome, auth, signIn included.
            NotyfiTheme.brandLight.ignoresSafeArea()

            GeometryReader { geo in
                ZStack(alignment: .top) {
                    stepContent(for: slotA)
                        .offset(x: slotAOffset * geo.size.width)
                        .zIndex(slotAZIndex)

                    stepContent(for: slotB)
                        .offset(x: slotBOffset * geo.size.width)
                        .zIndex(slotBZIndex)
                }
                .clipped()
                .onAppear { viewWidth = geo.size.width }
            }
        }
        // Always-present gradient fades — gives every page the soft top/bottom
        // edge. Non-interactive so taps pass through to content beneath.
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [NotyfiTheme.brandLight, NotyfiTheme.brandLight.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [NotyfiTheme.brandLight.opacity(0), NotyfiTheme.brandLight],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
        // Chrome elements sit on top of the gradient fades
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
                onGetStarted: { navigate(to: .currency) },
                onSignIn: { navigate(to: .signIn) }
            )
        case .howItWorks:
            OnboardingHowItWorksView()
        case .currency:
            OnboardingCurrencyView(currencyRawValue: $currencyRawValue)
        case .budget:
            OnboardingBudgetView(
                currencyCode: selectedCurrencyCode,
                amountText: $budgetAmountText
            )
        case .categories:
            OnboardingCategoriesView(selectedCategories: $selectedCategories)
        case .allocate:
            OnboardingAllocateView(
                currencyCode: selectedCurrencyCode,
                selectedCategories: selectedCategories,
                categoryBudgetTexts: $categoryBudgetTexts
            )
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
        case .signIn:
            OnboardingSignInView(authManager: authManager, onBack: { goBack() }, onSignUp: {
                // Don't push .signIn onto history — back from howItWorks should
                // return to welcome, not the sign-in page.
                navigate(to: .currency, pushCurrent: false)
            })
        }
    }

    // MARK: - Chrome

    private var topChrome: some View {
        HStack(spacing: 12) {
            OnboardingBackButton { goBack() }
            OnboardingProgressBar(current: progressStep, total: 8)
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

    private func navigate(to step: OnboardingStep, pushCurrent: Bool = true) {
        let wasChrome = hasChrome(currentStep)
        let willBeChrome = hasChrome(step)

        if pushCurrent { stepHistory.append(currentStep) }
        currentStep = step

        // Prepare chrome for boundary transitions
        if !wasChrome && willBeChrome {
            chromeVisible = true
            chromeOffset = 1
        } else if wasChrome && !willBeChrome {
            chromeOffset = 0
        }

        let outgoing: Slot = activeSlot
        let incoming: Slot = activeSlot == .a ? .b : .a

        // Snap the incoming slot into its off-screen start position instantly,
        // bypassing any in-flight animation that might have left it at the wrong offset.
        var snap = Transaction()
        snap.disablesAnimations = true
        withTransaction(snap) {
            switch incoming {
            case .a:
                slotA = step
                slotAOffset = 1    // off-screen right
                slotAZIndex = 1    // incoming on top for forward nav
                slotBZIndex = 0
            case .b:
                slotB = step
                slotBOffset = 1
                slotBZIndex = 1
                slotAZIndex = 0
            }
        }

        // Swap immediately so rapid taps see the correct active slot
        activeSlot = incoming

        withAnimation(.spring(response: 0.38, dampingFraction: 0.96)) {
            switch outgoing {
            case .a:
                slotAOffset = -1   // outgoing slides left
                slotBOffset = 0    // incoming arrives from right
            case .b:
                slotBOffset = -1
                slotAOffset = 0
            }
            if !wasChrome && willBeChrome { chromeOffset = 0 }
            else if wasChrome && !willBeChrome { chromeOffset = -1 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            chromeVisible = willBeChrome
        }
    }

    private func goBack() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        guard let prev = stepHistory.popLast() else { return }
        let wasChrome = hasChrome(currentStep)
        let willBeChrome = hasChrome(prev)
        currentStep = prev

        // Prepare chrome for boundary transitions
        if !wasChrome && willBeChrome {
            chromeVisible = true
            chromeOffset = -1
        } else if wasChrome && !willBeChrome {
            chromeOffset = 0
        }

        let outgoing: Slot = activeSlot
        let incoming: Slot = activeSlot == .a ? .b : .a

        // Snap the incoming slot into its off-screen start position instantly
        var snap = Transaction()
        snap.disablesAnimations = true
        withTransaction(snap) {
            switch incoming {
            case .a:
                slotA = prev
                slotAOffset = -1   // off-screen left for back nav
                slotAZIndex = 0
                slotBZIndex = 1    // outgoing stays on top
            case .b:
                slotB = prev
                slotBOffset = -1
                slotBZIndex = 0
                slotAZIndex = 1
            }
        }

        // Swap immediately
        activeSlot = incoming

        withAnimation(.spring(response: 0.38, dampingFraction: 0.96)) {
            switch outgoing {
            case .a:
                slotAOffset = 1    // outgoing slides right
                slotBOffset = 0    // incoming arrives from left
            case .b:
                slotBOffset = 1
                slotAOffset = 0
            }
            if !wasChrome && willBeChrome { chromeOffset = 0 }
            else if wasChrome && !willBeChrome { chromeOffset = 1 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            chromeVisible = willBeChrome
        }
    }

    private func handleContinue() {
        switch currentStep {
        case .howItWorks:
            navigate(to: .currency) // disabled — skipped
        case .currency:
            navigate(to: .budget)
        case .budget:
            let normalized = budgetAmountText
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespaces)
            guard let amount = Double(normalized), amount > 0 else { return }
            store.setMonthlySpendingLimit(amount)
            budgetAmountText = ""
            navigate(to: .categories)
        case .categories:
            navigate(to: .allocate)
        case .allocate:
            for (category, text) in categoryBudgetTexts {
                let normalized = text
                    .replacingOccurrences(of: ",", with: ".")
                    .trimmingCharacters(in: .whitespaces)
                if let amount = Double(normalized), amount > 0 {
                    store.setCategoryBudget(amount, for: category)
                }
            }
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
    case categories
    case allocate
    case notifications
    case beDetailed
    case inputMethods
    case widget
    case auth     // "Save your progress" — end of onboarding
    case signIn   // "Welcome back" — from welcome page sign-in link
}

#Preview {
    OnboardingFlowView(
        store: ExpenseJournalStore(previewMode: true),
        authManager: AuthManager()
    )
}
