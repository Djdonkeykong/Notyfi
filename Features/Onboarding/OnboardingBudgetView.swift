import SwiftUI

struct OnboardingBudgetView: View {
    let currencyCode: String
    @Binding var amountText: String

    @State private var sheetPresented = false

    private var parsedAmount: Double? {
        let normalized = amountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return normalized.isEmpty ? nil : Double(normalized)
    }

    private var formattedAmount: String? {
        guard let amount = parsedAmount, amount > 0 else { return nil }
        return amount.formattedCurrency(code: currencyCode)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Image("mascot-budget")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 260)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)

                Text("Set a monthly budget".notyfiLocalized)
                    .font(.notyfi(.title2, weight: .bold))
                    .padding(.bottom, 10)

                Text("Notyfi will track your spending against it and warn you when you're getting close.".notyfiLocalized)
                    .font(.notyfi(.body))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .lineSpacing(3)
                    .padding(.bottom, 28)

                budgetCard
            }
            .padding(.horizontal, 24)
        }
        .contentMargins(.top, 72, for: .scrollContent)
        .contentMargins(.bottom, 160, for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .background(NotyfiTheme.brandLight)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $sheetPresented) {
            BudgetInputSheet(currencyCode: currencyCode, amountText: $amountText)
                .presentationDetents([.height(220)])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.hidden)
                .presentationBackground(.regularMaterial)
        }
    }

    private var budgetCard: some View {
        Button { sheetPresented = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedAmount ?? "Tap to set amount".notyfiLocalized)
                        .font(.notyfi(.title3, weight: .bold))
                        .foregroundStyle(formattedAmount != nil ? .primary : NotyfiTheme.secondaryText)
                    Text("per month".notyfiLocalized)
                        .font(.notyfi(.subheadline))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                }
                Spacer()
                Image(systemName: formattedAmount != nil ? "pencil" : "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NotyfiTheme.brandPrimary)
                    .frame(width: 32, height: 32)
                    .background(NotyfiTheme.brandPrimary.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding(18)
            .background(NotyfiTheme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Budget Input Sheet

private struct BudgetInputSheet: View {
    let currencyCode: String
    @Binding var amountText: String

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 48, weight: .bold, design: .default))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)

                Text("per month".notyfiLocalized)
                    .font(.notyfi(.subheadline))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28)

            OnboardingPrimaryButton(title: "Set Budget") {
                dismiss()
            }
            .padding(.horizontal, 24)
        }
        .onAppear { focused = true }
    }
}

#Preview {
    OnboardingBudgetView(
        currencyCode: "USD",
        amountText: .constant("")
    )
    .background(NotyfiTheme.brandLight.ignoresSafeArea())
}
