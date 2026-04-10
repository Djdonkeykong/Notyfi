import SwiftUI

struct OnboardingAllocateView: View {
    let currencyCode: String
    let selectedCategories: Set<ExpenseCategory>
    @Binding var categoryBudgetTexts: [ExpenseCategory: String]

    @FocusState private var focusedCategory: ExpenseCategory?

    private var orderedCategories: [ExpenseCategory] {
        ExpenseCategory.allCases
            .filter { selectedCategories.contains($0) && $0 != .uncategorized }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Set category limits".notyfiLocalized)
                    .font(.notyfi(.title2, weight: .bold))
                    .padding(.bottom, 10)

                Text("Add a monthly limit for each category. Skip any you're not sure about — you can set these later.".notyfiLocalized)
                    .font(.notyfi(.body))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .lineSpacing(3)
                    .padding(.bottom, 24)

                categoryRows
            }
            .padding(.horizontal, 24)
        }
        .contentMargins(.top, 72, for: .scrollContent)
        .contentMargins(.bottom, 160, for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .background(NotyfiTheme.brandLight)
        .toolbar(.hidden, for: .navigationBar)
        .onTapGesture {
            focusedCategory = nil
        }
    }

    private var categoryRows: some View {
        VStack(spacing: 10) {
            ForEach(orderedCategories) { category in
                AllocateRow(
                    category: category,
                    currencyCode: currencyCode,
                    text: Binding(
                        get: { categoryBudgetTexts[category] ?? "" },
                        set: { categoryBudgetTexts[category] = $0 }
                    ),
                    isFocused: focusedCategory == category
                ) {
                    focusedCategory = category
                }
            }
        }
    }
}

private struct AllocateRow: View {
    let category: ExpenseCategory
    let currencyCode: String
    @Binding var text: String
    let isFocused: Bool
    let onTap: () -> Void

    @FocusState private var focused: Bool

    private var displayText: String {
        guard let amount = Double(text.replacingOccurrences(of: ",", with: ".")), amount > 0 else {
            return text
        }
        return amount.formattedCurrency(code: currencyCode)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(category.tint.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: category.symbol)
                        .font(.system(size: 16, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(category.tint)
                }

                Text(category.title)
                    .font(.notyfi(.subheadline, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 4) {
                    TextField("—", text: $text)
                        .keyboardType(.decimalPad)
                        .focused($focused)
                        .multilineTextAlignment(.trailing)
                        .font(.notyfi(.subheadline, weight: .medium))
                        .foregroundStyle(text.isEmpty ? NotyfiTheme.secondaryText : NotyfiTheme.brandPrimary)
                        .frame(width: 80)

                    Text("/mo".notyfiLocalized)
                        .font(.notyfi(.caption))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                }
            }
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        focused ? NotyfiTheme.brandPrimary : Color.primary.opacity(0.08),
                        lineWidth: focused ? 1.5 : 1
                    )
            }
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .onChange(of: focused) { _, isFocused in
            if isFocused { onTap() }
        }
        .animation(.easeInOut(duration: 0.15), value: focused)
    }
}

#Preview {
    OnboardingAllocateView(
        currencyCode: "USD",
        selectedCategories: Set(ExpenseCategory.allCases),
        categoryBudgetTexts: .constant([:])
    )
}
