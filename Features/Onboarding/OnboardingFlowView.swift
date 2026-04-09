import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var store: ExpenseJournalStore
    @ObservedObject var authManager: AuthManager

    @AppStorage("notyfi.onboarding.complete") private var isComplete = false
    @AppStorage(NotyfiCurrency.storageKey) private var currencyRawValue = NotyfiCurrencyPreference.auto.rawValue

    @State private var stepIndex: Int = 0
    @State private var goingForward: Bool = true

    // Resolved currency code for the budget step
    private var selectedCurrencyCode: String {
        NotyfiCurrencyPreference(rawValue: currencyRawValue)?.currencyCode
            ?? NotyfiCurrency.deviceCode
    }

    private enum Step: Int, CaseIterable {
        case welcome        = 0
        case howItWorks     = 1
        case currency       = 2
        case budget         = 3
        case notifications  = 4
        case auth           = 5
    }

    private var totalProgressSteps: Int { Step.allCases.count - 1 } // exclude welcome
    private var currentProgressStep: Int { max(0, stepIndex) }      // welcome = 0 progress

    var body: some View {
        ZStack {
            currentStepView
                .id(stepIndex)
                .transition(slideTransition)
        }
        .animation(.easeInOut(duration: 0.28), value: stepIndex)
        .onChange(of: authManager.isAuthenticated) { _, authenticated in
            if authenticated {
                isComplete = true
            }
        }
    }

    // MARK: - Step routing

    @ViewBuilder
    private var currentStepView: some View {
        switch Step(rawValue: stepIndex) ?? .welcome {
        case .welcome:
            OnboardingWelcomeView(
                onGetStarted: { advance() },
                onSignIn: { jumpTo(.auth) }
            )

        case .howItWorks:
            OnboardingHowItWorksView(
                step: currentProgressStep,
                totalSteps: totalProgressSteps,
                onNext: { advance() },
                onBack: { back() }
            )

        case .currency:
            OnboardingCurrencyView(
                step: currentProgressStep,
                totalSteps: totalProgressSteps,
                onNext: { preference in
                    currencyRawValue = preference.rawValue
                    advance()
                },
                onBack: { back() }
            )

        case .budget:
            OnboardingBudgetView(
                step: currentProgressStep,
                totalSteps: totalProgressSteps,
                currencyCode: selectedCurrencyCode,
                onNext: { amount in
                    if let amount {
                        store.setMonthlySpendingLimit(amount)
                    }
                    advance()
                },
                onBack: { back() }
            )

        case .notifications:
            OnboardingNotificationsView(
                step: currentProgressStep,
                totalSteps: totalProgressSteps,
                onNext: { advance() },
                onBack: { back() }
            )

        case .auth:
            OnboardingAuthView(
                onBack: { back() },
                authManager: authManager
            )
        }
    }

    // MARK: - Navigation

    private func advance() {
        let next = stepIndex + 1
        guard next < Step.allCases.count else { return }
        goingForward = true
        stepIndex = next
    }

    private func back() {
        guard stepIndex > 0 else { return }
        goingForward = false
        stepIndex -= 1
    }

    private func jumpTo(_ step: Step) {
        goingForward = step.rawValue > stepIndex
        stepIndex = step.rawValue
    }

    // MARK: - Transition

    private var slideTransition: AnyTransition {
        goingForward
            ? .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
              )
            : .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
              )
    }
}

#Preview {
    OnboardingFlowView(
        store: ExpenseJournalStore(previewMode: true),
        authManager: AuthManager()
    )
}
