import SwiftUI

struct OnboardingBudgetView: View {
    let currencyCode: String
    @Binding var amountText: String
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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingIllustration(symbol: "chart.bar.fill", size: 68)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)

                Text("Set a monthly budget")
                    .font(.notyfi(.title2, weight: .bold))
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
        .contentMargins(.top, 72, for: .scrollContent)
        .contentMargins(.bottom, 160, for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .background(NotyfiTheme.brandLight.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onTapGesture {
            fieldFocused = false
        }
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

            // Hidden text field drives keyboard input
            TextField("", text: $amountText)
                .keyboardType(.decimalPad)
                .focused($fieldFocused)
                .frame(width: 0, height: 0)
                .opacity(0)
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingBudgetView(currencyCode: "USD", amountText: .constant(""))
    }
}
