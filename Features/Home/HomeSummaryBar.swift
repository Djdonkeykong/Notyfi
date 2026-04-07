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
                                .lineLimit(2)

                            Text(subtitleText)
                                .font(.notyfi(.caption, weight: .medium))
                                .foregroundStyle(NotyfiTheme.secondaryText)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 12)

                        Image(systemName: "chevron.up.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(accentColor)
                            .frame(width: 36, height: 36)
                            .background {
                                Circle()
                                    .fill(accentColor.opacity(0.12))
                            }
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

                                Spacer(minLength: 12)

                                Text(statusText)
                                    .font(.notyfi(.caption, weight: .semibold))
                                    .foregroundStyle(accentColor)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        FooterMetricPill(
                            title: "Month",
                            value: budgetInsight.spentThisMonth.formattedCurrency(code: currencyCode),
                            tint: Color(red: 0.90, green: 0.36, blue: 0.34)
                        )

                        FooterMetricPill(
                            title: "Net",
                            value: signedCurrency(budgetInsight.netThisMonth),
                            tint: budgetInsight.netThisMonth >= 0
                                ? Color(red: 0.28, green: 0.71, blue: 0.45)
                                : Color(red: 0.90, green: 0.36, blue: 0.34)
                        )

                        FooterMetricPill(
                            title: trailingPillTitle,
                            value: trailingPillValue,
                            tint: trailingPillTint
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .buttonStyle(.plain)
    }

    private var accentColor: Color {
        switch budgetInsight.status {
        case .needsBudget:
            return NotyfiTheme.brandBlue
        case .balanced:
            return Color(red: 0.28, green: 0.71, blue: 0.45)
        case .caution:
            return Color(red: 0.90, green: 0.60, blue: 0.29)
        case .overBudget:
            return Color(red: 0.90, green: 0.36, blue: 0.34)
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

    private var subtitleText: String {
        guard budgetInsight.plan.hasSpendingLimit else {
            if let suggestion = budgetInsight.suggestedMonthlyBudget {
                return String(
                    format: "Tap to start with %@ and adjust later.".notyfiLocalized,
                    suggestion.formattedCurrency(code: currencyCode)
                )
            }

            return "Tap to add a simple monthly cap and category guides.".notyfiLocalized
        }

        if budgetInsight.status == .caution {
            return String(
                format: "At this pace you may land near %@.".notyfiLocalized,
                budgetInsight.projectedExpenseTotal.formattedCurrency(code: currencyCode)
            )
        }

        if budgetInsight.status == .overBudget {
            return "Open the sheet to tighten category caps or adjust the plan.".notyfiLocalized
        }

        return String(
            format: "Avg %@ per day so far.".notyfiLocalized,
            budgetInsight.averageDailySpend.formattedCurrency(code: currencyCode)
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

    private var trailingPillTitle: String {
        if insight.reviewCount > 0 {
            return "Review".notyfiLocalized
        }

        return insight.topCategory?.title ?? "Today".notyfiLocalized
    }

    private var trailingPillValue: String {
        if insight.reviewCount > 0 {
            return "\(insight.reviewCount)"
        }

        if let topCategory = insight.topCategory {
            return "\(Int((insight.topCategoryShare * 100).rounded()))%"
        }

        return insight.dayExpenseTotal.formattedCurrency(code: currencyCode)
    }

    private var trailingPillTint: Color {
        if insight.reviewCount > 0 {
            return NotyfiTheme.reviewTint
        }

        return insight.topCategory?.tint ?? NotyfiTheme.brandBlue
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

private struct FooterMetricPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.notyfiLocalized)
                .font(.notyfi(.caption2, weight: .semibold))
                .foregroundStyle(NotyfiTheme.secondaryText)

            Text(value)
                .font(.notyfi(.footnote, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.84))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
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
