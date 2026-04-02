import SwiftUI

struct HomeSummaryBar: View {
    let insight: JournalInsight
    let entryCount: Int
    let currencyCode: String

    var body: some View {
        SoftCapsule(horizontalPadding: 18, verticalPadding: 14) {
            HStack(spacing: 14) {
                SummaryItem(
                    symbol: "circle.fill",
                    symbolColor: NotelyTheme.reviewTint,
                    text: insight.dayTotal.formattedCurrency(code: currencyCode)
                )

                SummaryItem(
                    symbol: "circle.fill",
                    symbolColor: Color(red: 0.73, green: 0.40, blue: 0.47),
                    text: "\(entryCount)"
                )

                SummaryItem(
                    symbol: "circle.fill",
                    symbolColor: Color(red: 0.79, green: 0.65, blue: 0.36),
                    text: insight.topCategory?.title ?? "Notes"
                )

                if insight.reviewCount > 0 {
                    SummaryItem(
                        symbol: "circle.fill",
                        symbolColor: Color(red: 0.74, green: 0.47, blue: 0.86),
                        text: "\(insight.reviewCount)"
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

private struct SummaryItem: View {
    let symbol: String
    let symbolColor: Color
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 6, weight: .bold))
                .foregroundStyle(symbolColor)

            Text(text)
                .font(.notely(.footnote, weight: .medium))
                .foregroundStyle(.primary.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

#Preview {
    ZStack {
        NotelyTheme.background.ignoresSafeArea()
        VStack {
            Spacer()
            HomeSummaryBar(
                insight: JournalInsight(
                    dayTotal: 841,
                    monthTotal: 12877,
                    topCategory: .food,
                    reviewCount: 1
                ),
                entryCount: 4,
                currencyCode: "NOK"
            )
        }
    }
}
