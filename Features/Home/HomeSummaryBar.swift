import SwiftUI

struct HomeSummaryBar: View {
    let insight: JournalInsight
    let budgetInsight: BudgetInsight
    let currencyCode: String
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            Haptics.mediumImpact()
            onTap()
        }) {
            SoftSurface(cornerRadius: 30, padding: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Money pulse".notyfiLocalized)
                                .font(.notyfi(.footnote, weight: .semibold))
                                .foregroundStyle(NotyfiTheme.secondaryText)

                            Text(headlineText)
                                .font(.notyfi(.title3, weight: .semibold))
                                .foregroundStyle(.primary.opacity(0.88))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .frame(minHeight: 40, alignment: .topLeading)

                        Spacer(minLength: 12)

                        Text(statusEmoji)
                            .font(.system(size: 28))
                            .frame(width: 36, height: 36)
                            .accessibilityLabel(statusText)
                    }

                    if budgetInsight.plan.hasSpendingLimit {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: budgetInsight.spendingProgress)
                                .tint(accentColor)
                                .scaleEffect(x: 1, y: 1.35, anchor: .center)

                            HStack(spacing: 8) {
                                Text(
                                    String(
                                        format: "Spent %@ of %@".notyfiLocalized,
                                        budgetInsight.spentThisMonth.formattedCurrency(code: currencyCode),
                                        budgetInsight.plan.monthlySpendingLimit.formattedCurrency(code: currencyCode)
                                    )
                                )
                                .font(.notyfi(.caption, weight: .medium))
                                .foregroundStyle(NotyfiTheme.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)

                                Spacer(minLength: 12)

                                Text(statusText)
                                    .font(.notyfi(.caption, weight: .semibold))
                                    .foregroundStyle(accentColor)
                                    .lineLimit(1)
                            }
                        }
                        .frame(minHeight: 36, alignment: .topLeading)
                    }

                    HStack(spacing: 10) {
                        FooterMetricPill(
                            title: "Month",
                            value: budgetInsight.spentThisMonth.formattedCurrency(code: currencyCode),
                            tint: NotyfiTheme.expenseColor
                        )

                        FooterMetricPill(
                            title: "Net",
                            value: signedCurrency(budgetInsight.netThisMonth),
                            tint: budgetInsight.netThisMonth >= 0
                                ? NotyfiTheme.incomeColor
                                : NotyfiTheme.expenseColor
                        )

                        FooterMetricPill(
                            title: "Today",
                            value: insight.dayExpenseTotal.formattedCurrency(code: currencyCode),
                            tint: NotyfiTheme.brandBlue
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .buttonStyle(NoHighlightButtonStyle())
    }

    private var accentColor: Color {
        switch budgetInsight.status {
        case .needsBudget:
            return NotyfiTheme.brandBlue
        case .balanced:
            return NotyfiTheme.incomeColor
        case .caution:
            return Color(red: 0.90, green: 0.60, blue: 0.29)
        case .overBudget:
            return NotyfiTheme.expenseColor
        }
    }

    private var headlineText: String {
        guard budgetInsight.plan.hasSpendingLimit else {
            return "Set a gentle budget for this month".notyfiLocalized
        }

        if budgetInsight.remainingBudget >= 0 {
            return String(
                format: "%@ left this month".notyfiLocalized,
                budgetInsight.remainingBudget.formattedCurrency(code: currencyCode)
            )
        }

        return String(
            format: "%@ over budget".notyfiLocalized,
            abs(budgetInsight.remainingBudget).formattedCurrency(code: currencyCode)
        )
    }

    private var statusText: String {
        switch budgetInsight.status {
        case .needsBudget:
            return "No budget".notyfiLocalized
        case .balanced:
            return "On pace".notyfiLocalized
        case .caution:
            return "Watch pace".notyfiLocalized
        case .overBudget:
            return "Over".notyfiLocalized
        }
    }

    private var statusEmoji: String {
        switch budgetInsight.status {
        case .needsBudget:
            return "🙂"
        case .balanced:
            return "😌"
        case .caution:
            return "😬"
        case .overBudget:
            return "😵"
        }
    }

    private func signedCurrency(_ amount: Double) -> String {
        let formattedAmount = abs(amount).formattedCurrency(code: currencyCode)

        if amount > 0 {
            return "+\(formattedAmount)"
        }

        if amount < 0 {
            return "-\(formattedAmount)"
        }

        return formattedAmount
    }
}

private struct NoHighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

private struct FooterMetricPill: View {
    private let pillHeight: CGFloat = 58
    private let titleHeight: CGFloat = 14
    private let valueHeight: CGFloat = 18

    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.notyfiLocalized)
                .font(.notyfi(.caption2, weight: .semibold))
                .foregroundStyle(NotyfiTheme.secondaryText)
                .frame(height: titleHeight, alignment: .topLeading)

            Text(value)
                .font(.notyfi(.footnote, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.84))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .monospacedDigit()
                .frame(height: valueHeight, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: pillHeight, maxHeight: pillHeight, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.16), lineWidth: 1)
                }
        }
    }
}

#Preview {
    ZStack {
        NotyfiTheme.background.ignoresSafeArea()

        VStack {
            Spacer()

            HomeSummaryBar(
                insight: JournalInsight(
                    dayExpenseTotal: 810,
                    dayIncomeTotal: 0,
                    dayNetTotal: -810,
                    monthExpenseTotal: 13_880,
                    monthIncomeTotal: 28_000,
                    monthNetTotal: 14_120,
                    topCategory: .housing,
                    reviewCount: 2,
                    monthEntryCount: 8,
                    monthAveragePerEntry: 270.75,
                    topCategoryShare: 0.62,
                    categoryBreakdown: []
                ),
                budgetInsight: BudgetInsight(
                    plan: BudgetPlan(
                        monthlySpendingLimit: 16_000,
                        monthlySavingsTarget: 4_000,
                        categoryTargets: []
                    ),
                    status: .balanced,
                    spentThisMonth: 13_880,
                    incomeThisMonth: 28_000,
                    netThisMonth: 14_120,
                    averageDailySpend: 693,
                    projectedExpenseTotal: 15_600,
                    remainingBudget: 2_120,
                    spendingProgress: 0.86,
                    remainingSavingsTarget: -10_120,
                    savingsProgress: 1,
                    daysElapsed: 20,
                    daysInMonth: 30,
                    suggestedMonthlyBudget: nil,
                    categoryStatuses: []
                ),
                currencyCode: "NOK",
                onTap: {}
            )
        }
    }
}
