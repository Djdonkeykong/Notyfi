import SwiftUI

struct InsightsCard: View {
    let insight: JournalInsight
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quiet snapshot")
                .font(.notely(.caption, weight: .medium))
                .foregroundStyle(NotelyTheme.secondaryText)

            VStack(spacing: 10) {
                InsightRow(
                    title: "Spent today",
                    value: insight.dayExpenseTotal.formattedCurrency(code: currencyCode)
                )

                InsightRow(
                    title: "Net this month",
                    value: signedCurrency(insight.monthNetTotal)
                )

                InsightRow(
                    title: insight.reviewCount > 0 ? "Needs review" : "Top category",
                    value: insight.reviewCount > 0
                        ? "\(insight.reviewCount) note\(insight.reviewCount == 1 ? "" : "s")"
                        : (insight.topCategory?.title ?? "Quiet week")
                )
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(NotelyTheme.elevatedSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(NotelyTheme.surfaceBorder, lineWidth: 1)
                }
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

private struct InsightRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.notely(.footnote))
                .foregroundStyle(NotelyTheme.secondaryText)

            Spacer()

            Text(value)
                .font(.notely(.footnote, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.84))
                .multilineTextAlignment(.trailing)
                .minimumScaleFactor(0.75)
                .lineLimit(2)
        }
    }
}

#Preview {
    InsightsCard(
        insight: JournalInsight(
            dayExpenseTotal: 493,
            dayIncomeTotal: 0,
            dayNetTotal: -493,
            monthExpenseTotal: 12877,
            monthIncomeTotal: 28000,
            monthNetTotal: 15123,
            topCategory: .food,
            reviewCount: 1
        ),
        currencyCode: "NOK"
    )
    .padding()
    .background(NotelyTheme.background)
}
