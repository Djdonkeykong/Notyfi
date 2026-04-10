import SwiftUI

struct OnboardingBudgetView: View {
    let currencyCode: String
    @Binding var amountText: String
    @Binding var isFocused: Bool
    @FocusState private var fieldFocused: Bool

    @State private var scrollProxy: ScrollViewProxy? = nil

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
        ScrollViewReader { proxy in
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
                        .id("amountInput")
                }
                .padding(.horizontal, 24)
            }
            .ignoresSafeArea(.keyboard)
            .contentMargins(.top, 72, for: .scrollContent)
            .contentMargins(.bottom, 160, for: .scrollContent)
            .scrollBounceBehavior(.always)
            .scrollIndicators(.hidden)
            .onAppear { scrollProxy = proxy }
            .onChange(of: fieldFocused) { _, focused in
                isFocused = focused
                if focused {
                    withAnimation(.easeOut(duration: 0.25)) {
                        scrollProxy?.scrollTo("amountInput", anchor: UnitPoint(x: 0.5, y: 0.6))
                    }
                }
            }
            .onChange(of: isFocused) { _, v in
                if fieldFocused != v { fieldFocused = v }
            }
        }
        .background(NotyfiTheme.brandLight)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var amountInput: some View {
        Button {
            fieldFocused = true
        } label: {
            VStack(spacing: 5) {
                Text(amountText.isEmpty ? "Tap to enter" : displayAmount)
                    .font(.notyfi(.title, weight: .bold))
                    .foregroundStyle(amountText.isEmpty
                        ? NotyfiTheme.secondaryText
                        : NotyfiTheme.brandPrimary)
                    .animation(.easeInOut(duration: 0.15), value: amountText.isEmpty)

                Text("per month")
                    .font(.notyfi(.subheadline))
                    .foregroundStyle(NotyfiTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        fieldFocused ? NotyfiTheme.brandPrimary : Color.primary.opacity(0.08),
                        lineWidth: fieldFocused ? 1.5 : 1
                    )
            }
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .overlay {
            TextField("", text: $amountText)
                .keyboardType(.decimalPad)
                .focused($fieldFocused)
                .frame(width: 0, height: 0)
                .opacity(0)
        }
    }
}

#Preview {
    OnboardingBudgetView(
        currencyCode: "USD",
        amountText: .constant(""),
        isFocused: .constant(false)
    )
    .background(NotyfiTheme.brandLight.ignoresSafeArea())
}
