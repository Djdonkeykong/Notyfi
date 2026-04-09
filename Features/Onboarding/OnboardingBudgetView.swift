import SwiftUI

struct OnboardingBudgetView: View {
    let step: Int
    let totalSteps: Int
    let currencyCode: String
    let onNext: (Double?) -> Void
    let onBack: () -> Void

    @State private var amountText: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var fieldFocused: Bool

    private var parsedAmount: Double? {
        let normalized = amountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return normalized.isEmpty ? nil : Double(normalized)
    }

    private var displayAmount: String {
        guard let amount = parsedAmount, amount > 0 else {
            return amountText.isEmpty ? "0" : amountText
        }
        return amount.formattedCurrency(code: currencyCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingNavBar(currentStep: step, totalSteps: totalSteps, onBack: onBack)
                .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    illustration
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)

                    Text("Set a monthly budget")
                        .font(.notyfi(.title, weight: .bold))
                        .padding(.bottom, 10)

                    Text("Notyfi will track your spending against it and warn you when you're getting close.")
                        .font(.notyfi(.body))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                        .lineSpacing(3)
                        .padding(.bottom, 28)

                    amountInput
                }
                .padding(.horizontal, 24)
            }

            bottomActions
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .padding(.top, 16)
        }
        .background(NotyfiTheme.brandLight.ignoresSafeArea())
        .onTapGesture {
            fieldFocused = false
        }
    }

    // MARK: - Subviews

    private var illustration: some View {
        OnboardingIllustration(symbol: "chart.bar.fill", size: 68)
    }

    private var amountInput: some View {
        VStack(spacing: 12) {
            Button {
                fieldFocused = true
            } label: {
                VStack(spacing: 6) {
                    Text(amountText.isEmpty ? "Tap to enter" : displayAmount)
                        .font(.notyfi(.largeTitle, weight: .bold))
                        .foregroundStyle(amountText.isEmpty
                            ? NotyfiTheme.secondaryText
                            : NotyfiTheme.brandPrimary)
                        .animation(.easeInOut(duration: 0.15), value: amountText.isEmpty)

                    Text("per month")
                        .font(.notyfi(.subheadline))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            fieldFocused ? NotyfiTheme.brandPrimary : Color.primary.opacity(0.08),
                            lineWidth: fieldFocused ? 1.5 : 1
                        )
                }
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            // Hidden text field for keyboard input
            TextField("", text: $amountText)
                .keyboardType(.decimalPad)
                .focused($fieldFocused)
                .frame(width: 0, height: 0)
                .opacity(0)
        }
    }

    private var bottomActions: some View {
        VStack(spacing: 14) {
            OnboardingPrimaryButton(
                title: parsedAmount != nil ? "Set Budget" : "Continue"
            ) {
                onNext(parsedAmount)
            }

            OnboardingSkipButton {
                onNext(nil)
            }
        }
    }
}

#Preview {
    OnboardingBudgetView(step: 3, totalSteps: 5, currencyCode: "USD", onNext: { _ in }, onBack: {})
}
