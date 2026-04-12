import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var store: ExpenseJournalStore
    @ObservedObject var authManager: AuthManager

    @AppStorage("notyfi.onboarding.complete") private var isComplete = false
    @AppStorage(NotyfiCurrency.storageKey) private var currencyRawValue = NotyfiCurrencyPreference.auto.rawValue

    @State private var currentStep: OnboardingStep = .welcome
    @State private var stepHistory: [OnboardingStep] = []
    @State private var budgetAmountText: String = ""
    @State private var selectedCategories: Set<ExpenseCategory> = []
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

    // Top gradient is shown with a delay when entering chrome pages so it doesn't
    // overlap content (e.g. language pill) on non-chrome pages sliding out.
    // Bottom gradient appears immediately on entry and hides immediately on exit.
    @State private var topGradientVisible: Bool = false
    @State private var bottomGradientVisible: Bool = false

    // Captured from GeometryReader so overlays can use it
    @State private var viewWidth: CGFloat = 390

    private var progressStep: Int {
        switch currentStep {
        case .currency: return 1
        case .budget: return 2
        case .categories: return 3
        case .allocate: return 4
        case .notifications: return 5
        case .inputMethods: return 6
        case .widget: return 7
        default: return 0
        }
    }

    private var continueTitle: String { "Continue".notyfiLocalized }

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
        // Gradient fades — only shown on chrome steps. Hidden immediately when leaving
        // chrome pages, but shown with a delay when entering them so non-chrome content
        // (e.g. language pill) isn't covered while sliding out.
        // Non-interactive so taps pass through to content beneath.
        .overlay(alignment: .top) {
            if topGradientVisible {
                LinearGradient(
                    stops: [
                        .init(color: NotyfiTheme.brandLight, location: 0),
                        .init(color: NotyfiTheme.brandLight, location: 0.50),
                        .init(color: NotyfiTheme.brandLight.opacity(0), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if bottomGradientVisible || currentStep == .auth {
                LinearGradient(
                    colors: [NotyfiTheme.brandLight.opacity(0), NotyfiTheme.brandLight],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
                .transition(.opacity)
            }
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

        // Top gradient: delayed on entry so it doesn't cover non-chrome content sliding out.
        // Bottom gradient: immediate on entry/exit.
        if !wasChrome && willBeChrome {
            bottomGradientVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                topGradientVisible = true
            }
        } else if wasChrome && !willBeChrome {
            topGradientVisible = false
            bottomGradientVisible = false
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

        // Hide gradients immediately when returning to non-chrome pages (back button unobstructed),
        // show with delay (top) or immediately (bottom) when pushing into chrome pages.
        if wasChrome && !willBeChrome {
            topGradientVisible = false
            bottomGradientVisible = false
        } else if !wasChrome && willBeChrome {
            bottomGradientVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                topGradientVisible = true
            }
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
    .environmentObject(LanguageManager())
}
