import SwiftUI

private enum MoneyPlanFocusField: Hashable {
    case monthlyBudget
    case savingsTarget
    case category(ExpenseCategory)
}

struct StatsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HomeViewModel

    @State private var monthlyBudgetText = ""
    @State private var savingsTargetText = ""
    @State private var categoryBudgetTexts: [ExpenseCategory: String] = [:]
    @FocusState private var focusedField: MoneyPlanFocusField?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            NotyfiTheme.background.ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header

                    heroCard

                    SectionHeader(title: "Overview")
                    LazyVGrid(columns: columns, spacing: 12) {
                        OverviewMetricTile(
                            title: "Spend",
                            value: viewModel.insight.monthExpenseTotal.formattedCurrency(code: viewModel.currencyCode),
                            caption: monthLabel,
                            tint: Color(red: 0.90, green: 0.36, blue: 0.34),
                            symbol: "arrow.up.right.circle.fill"
                        )

                        OverviewMetricTile(
                            title: "Income",
                            value: viewModel.insight.monthIncomeTotal.formattedCurrency(code: viewModel.currencyCode),
                            caption: "Captured so far".notyfiLocalized,
                            tint: Color(red: 0.28, green: 0.71, blue: 0.45),
                            symbol: "arrow.down.left.circle.fill"
                        )

                        OverviewMetricTile(
                            title: "Net",
                            value: signedCurrency(viewModel.insight.monthNetTotal),
                            caption: "Income minus spend".notyfiLocalized,
                            tint: viewModel.insight.monthNetTotal >= 0
                                ? Color(red: 0.28, green: 0.71, blue: 0.45)
                                : Color(red: 0.90, green: 0.36, blue: 0.34),
                            symbol: "chart.line.uptrend.xyaxis"
                        )

                        OverviewMetricTile(
                            title: "Avg / day",
                            value: viewModel.budgetInsight.averageDailySpend.formattedCurrency(code: viewModel.currencyCode),
                            caption: String(
                                format: "Based on %d days".notyfiLocalized,
                                viewModel.budgetInsight.daysElapsed
                            ),
                            tint: NotyfiTheme.brandBlue,
                            symbol: "calendar"
                        )
                    }

                    SectionHeader(title: "Plan")
                    StatsCard {
                        VStack(spacing: 0) {
                            BudgetAmountInputRow(
                                icon: "target",
                                title: "Monthly spending cap",
                                subtitle: "One gentle limit for the whole month",
                                text: $monthlyBudgetText,
                                currencyCode: viewModel.currencyCode,
                                focusedField: $focusedField,
                                field: .monthlyBudget
                            )

                            Divider()

                            BudgetAmountInputRow(
                                icon: "leaf.fill",
                                title: "Savings target",
                                subtitle: "How much you want to keep after expenses",
                                text: $savingsTargetText,
                                currencyCode: viewModel.currencyCode,
                                focusedField: $focusedField,
                                field: .savingsTarget
                            )
                        }
                    }

                    if !viewModel.budgetPlan.hasSpendingLimit,
                       let suggestion = viewModel.suggestedMonthlyBudgetAmount() {
                        Button {
                            monthlyBudgetText = editableAmountString(suggestion)
                            viewModel.setMonthlySpendingLimit(suggestion)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .bold))

                                Text(
                                    String(
                                        format: "Use suggested cap %@".notyfiLocalized,
                                        suggestion.formattedCurrency(code: viewModel.currencyCode)
                                    )
                                )
                                .font(.notyfi(.footnote, weight: .semibold))
                            }
                            .foregroundStyle(NotyfiTheme.brandBlue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background {
                                Capsule()
                                    .fill(NotyfiTheme.brandBlue.opacity(0.08))
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                    }

                    SectionHeader(title: "Category guides")
                    StatsCard {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.budgetInsight.categoryStatuses.enumerated()), id: \.element.id) { index, status in
                                CategoryBudgetInputRow(
                                    status: status,
                                    text: binding(for: status.category),
                                    currencyCode: viewModel.currencyCode,
                                    focusedField: $focusedField,
                                    field: .category(status.category)
                                )

                                if index < viewModel.budgetInsight.categoryStatuses.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }

                    SectionHeader(title: "Attention")
                    StatsCard {
                        VStack(spacing: 0) {
                            HighlightRow(
                                icon: "eye",
                                tint: NotyfiTheme.reviewTint,
                                title: "Needs review",
                                value: "\(viewModel.insight.reviewCount)"
                            )

                            if viewModel.budgetPlan.hasSavingsTarget {
                                Divider()

                                HighlightRow(
                                    icon: "leaf.fill",
                                    tint: Color(red: 0.28, green: 0.71, blue: 0.45),
                                    title: "Savings target",
                                    value: savingsLabel
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .safeAreaPadding(.top, 14)
                .padding(.bottom, 28)
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear(perform: syncInputs)
        .onChange(of: monthlyBudgetText) { _, newValue in
            viewModel.setMonthlySpendingLimit(parsedAmount(from: newValue))
        }
        .onChange(of: savingsTargetText) { _, newValue in
            viewModel.setMonthlySavingsTarget(parsedAmount(from: newValue))
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done".notyfiLocalized) {
                    focusedField = nil
                }
                .font(.notyfi(.footnote, weight: .semibold))
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Money plan".notyfiLocalized)
                    .font(.notyfi(.title3, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.84))

                Text(monthLabel)
                    .font(.notyfi(.footnote, weight: .medium))
                    .foregroundStyle(NotyfiTheme.secondaryText)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .frame(width: 38, height: 38)
                    .background {
                        Circle()
                            .fill(NotyfiTheme.elevatedSurface)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 22)
    }

    private var heroCard: some View {
        SoftSurface(cornerRadius: 34, padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.budgetInsight.status.title)
                        .font(.notyfi(.title2, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.88))

                    Text(heroSubtitle)
                        .font(.notyfi(.footnote))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                }

                if viewModel.budgetPlan.hasSpendingLimit {
                    VStack(alignment: .leading, spacing: 10) {
                        ProgressView(value: viewModel.budgetInsight.spendingProgress)
                            .tint(statusTint)
                            .scaleEffect(x: 1, y: 1.5, anchor: .center)

                        HStack(alignment: .firstTextBaseline) {
                            Text(heroPrimaryValue)
                                .font(.notyfi(.largeTitle, weight: .bold))
                                .foregroundStyle(.primary.opacity(0.9))
                                .monospacedDigit()
                                .minimumScaleFactor(0.75)

                            Spacer(minLength: 12)

                            Text(heroSecondaryValue)
                                .font(.notyfi(.footnote, weight: .semibold))
                                .foregroundStyle(statusTint)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        MoneyPlanBadge(
                            symbol: "arrow.up.right.circle.fill",
                            tint: Color(red: 0.90, green: 0.36, blue: 0.34),
                            title: "Spent",
                            value: viewModel.insight.monthExpenseTotal.formattedCurrency(code: viewModel.currencyCode)
                        )

                        MoneyPlanBadge(
                            symbol: "arrow.down.left.circle.fill",
                            tint: Color(red: 0.28, green: 0.71, blue: 0.45),
                            title: "Income",
                            value: viewModel.insight.monthIncomeTotal.formattedCurrency(code: viewModel.currencyCode)
                        )
                    }
                }
            }
        }
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: viewModel.selectedDate)
    }

    private var heroSubtitle: String {
        if viewModel.budgetPlan.hasSpendingLimit {
            return String(
                format: "Spent %@ over %@ tracked days.".notyfiLocalized,
                viewModel.insight.monthExpenseTotal.formattedCurrency(code: viewModel.currencyCode),
                "\(viewModel.budgetInsight.daysElapsed)"
            )
        }

        return "Start with one monthly cap, then add category guides only where they help.".notyfiLocalized
    }

    private var heroPrimaryValue: String {
        if viewModel.budgetInsight.remainingBudget >= 0 {
            return viewModel.budgetInsight.remainingBudget.formattedCurrency(code: viewModel.currencyCode)
        }

        return abs(viewModel.budgetInsight.remainingBudget).formattedCurrency(code: viewModel.currencyCode)
    }

    private var heroSecondaryValue: String {
        if viewModel.budgetInsight.remainingBudget >= 0 {
            return "left".notyfiLocalized
        }

        return "over".notyfiLocalized
    }

    private var savingsLabel: String {
        if viewModel.budgetInsight.remainingSavingsTarget <= 0 {
            return "Reached".notyfiLocalized
        }

        return String(
            format: "%@ to go".notyfiLocalized,
            viewModel.budgetInsight.remainingSavingsTarget.formattedCurrency(code: viewModel.currencyCode)
        )
    }

    private var statusTint: Color {
        switch viewModel.budgetInsight.status {
        case .needsBudget:
            return NotyfiTheme.brandBlue
        case .balanced:
            return Color(red: 0.28, green: 0.71, blue: 0.45)
        case .caution:
            return NotyfiTheme.reviewTint
        case .overBudget:
            return Color(red: 0.90, green: 0.36, blue: 0.34)
        }
    }

    private func binding(for category: ExpenseCategory) -> Binding<String> {
        Binding(
            get: { categoryBudgetTexts[category] ?? editableAmountString(viewModel.budgetPlan.target(for: category)) },
            set: { newValue in
                categoryBudgetTexts[category] = newValue
                viewModel.setCategoryBudget(parsedAmount(from: newValue), for: category)
            }
        )
    }

    private func syncInputs() {
        monthlyBudgetText = editableAmountString(viewModel.budgetPlan.monthlySpendingLimit)
        savingsTargetText = editableAmountString(viewModel.budgetPlan.monthlySavingsTarget)

        var nextCategoryTexts: [ExpenseCategory: String] = [:]
        for status in viewModel.budgetInsight.categoryStatuses {
            nextCategoryTexts[status.category] = editableAmountString(status.target)
        }
        categoryBudgetTexts = nextCategoryTexts
    }

    private func parsedAmount(from text: String) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return 0
        }

        let normalized = trimmed
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }

        return Double(normalized) ?? 0
    }

    private func editableAmountString(_ amount: Double) -> String {
        guard amount > 0 else {
            return ""
        }

        if amount.rounded() == amount {
            return String(Int(amount))
        }

        return String(format: "%.2f", amount)
    }

    private func signedCurrency(_ amount: Double) -> String {
        let formattedAmount = abs(amount).formattedCurrency(code: viewModel.currencyCode)

        if amount > 0 {
            return "+\(formattedAmount)"
        }

        if amount < 0 {
            return "-\(formattedAmount)"
        }

        return formattedAmount
    }
}

private struct StatsCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(NotyfiTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(NotyfiTheme.surfaceBorder, lineWidth: 1)
                    }
                    .shadow(color: NotyfiTheme.shadow, radius: 16, x: 0, y: 8)
            }
    }
}

private struct OverviewMetricTile: View {
    let title: String
    let value: String
    let caption: String
    let tint: Color
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)

                Text(title.notyfiLocalized)
                    .font(.notyfi(.caption, weight: .semibold))
                    .foregroundStyle(NotyfiTheme.secondaryText)
            }

            Text(value)
                .font(.notyfi(.headline, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.88))
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .monospacedDigit()

            Text(caption.notyfiLocalized)
                .font(.notyfi(.caption2, weight: .medium))
                .foregroundStyle(NotyfiTheme.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(NotyfiTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(NotyfiTheme.surfaceBorder, lineWidth: 1)
                }
        }
    }
}

private struct BudgetAmountInputRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var text: String
    let currencyCode: String
    @FocusState.Binding var focusedField: MoneyPlanFocusField?
    let field: MoneyPlanFocusField

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(NotyfiTheme.brandBlue)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(title.notyfiLocalized)
                    .font(.notyfi(.body))
                    .foregroundStyle(.primary.opacity(0.82))

                Text(subtitle.notyfiLocalized)
                    .font(.notyfi(.caption))
                    .foregroundStyle(NotyfiTheme.secondaryText)
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                TextField("0".notyfiLocalized, text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.notyfi(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.86))
                    .frame(width: 112)
                    .focused($focusedField, equals: field)

                Text(currencyCode)
                    .font(.notyfi(.caption, weight: .semibold))
                    .foregroundStyle(NotyfiTheme.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(NotyfiTheme.elevatedSurface)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = field
        }
    }
}

private struct CategoryBudgetInputRow: View {
    let status: BudgetCategoryStatus
    @Binding var text: String
    let currencyCode: String
    @FocusState.Binding var focusedField: MoneyPlanFocusField?
    let field: MoneyPlanFocusField

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: status.category.symbol)
                    .foregroundStyle(status.category.tint)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text(status.category.title)
                        .font(.notyfi(.body))
                        .foregroundStyle(.primary.opacity(0.82))

                    Text(status.spent.formattedCurrency(code: currencyCode))
                        .font(.notyfi(.caption))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    TextField("Cap".notyfiLocalized, text: $text)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.notyfi(.subheadline, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.86))
                        .frame(width: 104)
                        .focused($focusedField, equals: field)

                    Text(currencyCode)
                        .font(.notyfi(.caption, weight: .semibold))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(NotyfiTheme.elevatedSurface)
                }
            }

            if status.hasTarget {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: status.progress)
                        .tint(status.remaining >= 0 ? status.category.tint : Color(red: 0.90, green: 0.36, blue: 0.34))
                        .scaleEffect(x: 1, y: 1.2, anchor: .center)

                    Text(remainingLabel)
                        .font(.notyfi(.caption2, weight: .medium))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = field
        }
    }

    private var remainingLabel: String {
        if status.remaining >= 0 {
            return String(
                format: "%@ left in %@".notyfiLocalized,
                status.remaining.formattedCurrency(code: currencyCode),
                status.category.title
            )
        }

        return String(
            format: "%@ over in %@".notyfiLocalized,
            abs(status.remaining).formattedCurrency(code: currencyCode),
            status.category.title
        )
    }
}

private struct HighlightRow: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 18)

            Text(title.notyfiLocalized)
                .font(.notyfi(.body))
                .foregroundStyle(.primary.opacity(0.82))

            Spacer()

            Text(value)
                .font(.notyfi(.subheadline, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.82))
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}

private struct MoneyPlanBadge: View {
    let symbol: String
    let tint: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(tint.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title.notyfiLocalized)
                    .font(.notyfi(.caption, weight: .semibold))
                    .foregroundStyle(NotyfiTheme.secondaryText)

                Text(value)
                    .font(.notyfi(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.88))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(NotyfiTheme.elevatedSurface)
        }
    }
}

#Preview {
    StatsSheetView(viewModel: HomeViewModel(store: ExpenseJournalStore(previewMode: true)))
}
