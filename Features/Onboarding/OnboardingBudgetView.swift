import SwiftUI

struct OnboardingBudgetView: View {
    let currencyCode: String
    @Binding var amountText: String

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
            Image("mascot-budget")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 180)
                .padding(.top, 8)

            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("Set a monthly budget")
                    .font(.notyfi(.title2, weight: .bold))

                Text("Notyfi will track your spending against it and warn you when you're getting close.")
                    .font(.notyfi(.body))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            Spacer(minLength: 24)

            VStack(spacing: 4) {
                Text(displayAmount)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(amountText.isEmpty ? NotyfiTheme.secondaryText.opacity(0.4) : .primary)
                    .animation(.easeInOut(duration: 0.15), value: amountText.isEmpty)
                    .contentTransition(.numericText())

                Text("per month")
                    .font(.notyfi(.subheadline))
                    .foregroundStyle(NotyfiTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 24)

            numpad
                .padding(.horizontal, 24)
                .padding(.bottom, 140)
        }
        .padding(.top, 80)
        .background(NotyfiTheme.brandLight)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var numpad: some View {
        VStack(spacing: 10) {
            ForEach([["1","2","3"], ["4","5","6"], ["7","8","9"], [".", "0", "del"]], id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { key in
                        NumpadKey(key: key) { handleKey(key) }
                    }
                }
            }
        }
    }

    private func handleKey(_ key: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch key {
        case "del":
            if !amountText.isEmpty { amountText.removeLast() }
        case ".":
            if !amountText.contains(".") {
                amountText += amountText.isEmpty ? "0." : "."
            }
        default:
            if amountText == "0" { amountText = key; return }
            if let dotIndex = amountText.firstIndex(of: ".") {
                let decimals = amountText.distance(from: amountText.index(after: dotIndex), to: amountText.endIndex)
                if decimals >= 2 { return }
            }
            amountText += key
        }
    }
}

private struct NumpadKey: View {
    let key: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if key == "del" {
                    Image(systemName: "delete.left")
                        .font(.system(size: 20, weight: .medium))
                } else {
                    Text(key)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingBudgetView(
        currencyCode: "USD",
        amountText: .constant("")
    )
    .background(NotyfiTheme.brandLight.ignoresSafeArea())
}
