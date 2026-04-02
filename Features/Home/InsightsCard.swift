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
                    value: insight.dayTotal.formattedCurrency(code: currencyCode)
                )

                InsightRow(
                    title: "Spent this month",
                    value: insight.monthTotal.formattedCurrency(code: currencyCode)
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
            dayTotal: 493,
            monthTotal: 12877,
            topCategory: .food,
            reviewCount: 1
        ),
        currencyCode: "NOK"
    )
    .padding()
    .background(NotelyTheme.background)
}
