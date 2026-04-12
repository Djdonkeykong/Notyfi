import SwiftUI

struct OnboardingAllocateView: View {
    let currencyCode: String
    let selectedCategories: Set<ExpenseCategory>
    @Binding var categoryBudgetTexts: [ExpenseCategory: String]

    @State private var editingCategory: ExpenseCategory?

    private struct CategoryGroup {
        let title: String
        let color: Color
        let categories: [ExpenseCategory]
    }

    private let allGroups: [CategoryGroup] = [
        CategoryGroup(title: "Essentials", color: Color(red: 0.93, green: 0.45, blue: 0.28), categories: [.housing, .bills]),
        CategoryGroup(title: "Food & Drink", color: Color(red: 0.25, green: 0.70, blue: 0.42), categories: [.food, .groceries]),
        CategoryGroup(title: "Transport", color: Color(red: 0.28, green: 0.52, blue: 0.92), categories: [.transport, .travel]),
        CategoryGroup(title: "Lifestyle", color: Color(red: 0.52, green: 0.38, blue: 0.92), categories: [.shopping, .social, .entertainment, .health]),
    ]

    private var activeGroups: [CategoryGroup] {
        allGroups.compactMap { group in
            let filtered = group.categories.filter { selectedCategories.contains($0) }
            return filtered.isEmpty ? nil : CategoryGroup(title: group.title, color: group.color, categories: filtered)
        }
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
        .sheet(item: $editingCategory) { category in
            AllocateLimitSheet(
                category: category,
                currencyCode: currencyCode,
                text: Binding(
                    get: { categoryBudgetTexts[category] ?? "" },
                    set: { categoryBudgetTexts[category] = $0 }
                )
            )
            .presentationDetents([.height(220)])
            .presentationCornerRadius(28)
            .presentationDragIndicator(.hidden)
            .presentationBackground(.regularMaterial)
        }
    }

    private var categoryRows: some View {
        Group {
            if activeGroups.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(activeGroups, id: \.title) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.title.notyfiLocalized)
                                .font(.notyfi(.subheadline, weight: .bold))
                                .foregroundStyle(group.color)

                            VStack(spacing: 10) {
                                ForEach(group.categories) { category in
                                    AllocateRow(
                                        category: category,
                                        currencyCode: currencyCode,
                                        text: categoryBudgetTexts[category] ?? ""
                                    ) {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        editingCategory = category
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image("mascot-budget")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .padding(.bottom, 4)

            Text("No categories selected".notyfiLocalized)
                .font(.notyfi(.title3, weight: .semibold))
                .foregroundStyle(.primary)

            Text("Go back and select some categories to set spending limits. You can always do this later in the app.".notyfiLocalized)
                .font(.notyfi(.body))
                .foregroundStyle(NotyfiTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.horizontal, 8)
    }
}

private struct AllocateRow: View {
    let category: ExpenseCategory
    let currencyCode: String
    let text: String
    let onTap: () -> Void

    private var formattedAmount: String? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(normalized), amount > 0 else { return nil }
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

                VStack(alignment: .leading, spacing: 4) {
                    Text(category.title)
                        .font(.notyfi(.subheadline, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(formattedAmount ?? "Tap to set limit".notyfiLocalized)
                        .font(.notyfi(.caption))
                        .foregroundStyle(formattedAmount != nil ? NotyfiTheme.brandPrimary : NotyfiTheme.secondaryText)
                }

                Spacer()

                Image(systemName: formattedAmount != nil ? "pencil" : "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NotyfiTheme.brandPrimary)
                    .frame(width: 28, height: 28)
                    .background(NotyfiTheme.brandPrimary.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding(16)
            .background(NotyfiTheme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

private struct AllocateLimitSheet: View {
    let category: ExpenseCategory
    let currencyCode: String
    @Binding var text: String

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 48, weight: .bold, design: .default))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)

                Text("per month for \(category.title)".notyfiLocalized)
                    .font(.notyfi(.subheadline))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28)

            OnboardingPrimaryButton(title: "Set Limit".notyfiLocalized) {
                dismiss()
            }
            .padding(.horizontal, 24)
        }
        .onAppear { focused = true }
    }
}

#Preview {
    OnboardingAllocateView(
        currencyCode: "USD",
        selectedCategories: Set(ExpenseCategory.allCases),
        categoryBudgetTexts: .constant([:])
    )
}
