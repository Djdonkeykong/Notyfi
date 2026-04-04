import SwiftUI

struct HomeSummaryBar: View {
    let insight: JournalInsight
    let entryCount: Int
    let currencyCode: String
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            Haptics.mediumImpact()
            onTap()
        }) {
            SoftCapsule(horizontalPadding: 22, verticalPadding: 16) {
                HStack(spacing: 18) {
                    SummaryItem(
                        symbol: "sun.max.fill",
                        symbolColor: NotelyTheme.reviewTint,
                        text: insight.dayExpenseTotal.formattedCurrency(code: currencyCode)
                    )

                    SummaryItem(
                        symbol: "calendar",
                        symbolColor: insight.monthNetTotal >= 0
                            ? Color(red: 0.28, green: 0.71, blue: 0.45)
                            : Color(red: 0.90, green: 0.36, blue: 0.34),
                        text: Self.signedCurrency(insight.monthNetTotal, currencyCode: currencyCode)
                    )

                    SummaryItem(
                        symbol: insight.topCategory?.symbol ?? "chart.pie.fill",
                        symbolColor: insight.topCategory?.tint ?? Color(red: 0.79, green: 0.65, blue: 0.36),
                        text: insight.topCategory.map { category in
                            "\(category.title) \(Self.shareText(insight.topCategoryShare))"
                        } ?? String.notelyNotesCount(entryCount)
                    )

                    if insight.reviewCount > 0 {
                        SummaryItem(
                            symbol: "wand.and.stars",
                            symbolColor: Color(red: 0.74, green: 0.47, blue: 0.86),
                            text: "\(insight.reviewCount)"
                        )
                    }
                }
                .frame(minHeight: 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .buttonStyle(.plain)
    }

    private static func shareText(_ share: Double) -> String {
        "\(Int((share * 100).rounded()))%"
    }

    private static func signedCurrency(_ amount: Double, currencyCode: String) -> String {
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

struct HomeSnapshotCard: View {
    let insight: JournalInsight
    let currencyCode: String

    var body: some View {
        SoftSurface(cornerRadius: 34, padding: 18) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Monthly insight".notelyLocalized)
                            .font(.notely(.headline, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.9))

                        Text(insightHeadline)
                            .font(.notely(.footnote))
                            .foregroundStyle(NotelyTheme.secondaryText)
                    }

                    Spacer()

                    if insight.reviewCount > 0 {
                        Label("\(insight.reviewCount)", systemImage: "wand.and.stars")
                            .font(.notely(.footnote, weight: .semibold))
                            .foregroundStyle(Color(red: 0.74, green: 0.47, blue: 0.86))
                    }
                }

                HStack(spacing: 12) {
                    SnapshotMetricTile(
                        title: "Spend",
                        value: insight.monthExpenseTotal.formattedCurrency(code: currencyCode),
                        caption: "This month",
                        symbol: "sun.max.fill",
                        tint: Color(red: 0.90, green: 0.36, blue: 0.34)
                    )

                    SnapshotMetricTile(
                        title: "Income",
                        value: insight.monthIncomeTotal.formattedCurrency(code: currencyCode),
                        caption: String.notelyNotesCount(insight.monthEntryCount),
                        symbol: "arrow.down.circle.fill",
                        tint: Color(red: 0.28, green: 0.71, blue: 0.45)
                    )

                    SnapshotMetricTile(
                        title: "Net",
                        value: Self.signedCurrency(insight.monthNetTotal, currencyCode: currencyCode),
                        caption: "Balance",
                        symbol: "chart.bar.fill",
                        tint: insight.monthNetTotal >= 0
                            ? Color(red: 0.28, green: 0.71, blue: 0.45)
                            : Color(red: 0.90, green: 0.36, blue: 0.34)
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Top categories".notelyLocalized)
                        .font(.notely(.footnote, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.88))

                    if insight.categoryBreakdown.isEmpty {
                        EmptyCategoryBreakdownRow()
                    } else {
                        VStack(spacing: 10) {
                            ForEach(insight.categoryBreakdown.prefix(4)) { breakdown in
                                CategoryBreakdownRow(
                                    breakdown: breakdown,
                                    currencyCode: currencyCode
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var insightHeadline: String {
        guard let topCategory = insight.topCategory else {
            return "Start adding notes to see where your money goes.".notelyLocalized
        }

        let share = Int((insight.topCategoryShare * 100).rounded())
        return String(
            format: "Top category insight format".notelyLocalized,
            topCategory.title,
            share
        )
    }

    private static func signedCurrency(_ amount: Double, currencyCode: String) -> String {
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

private struct SummaryItem: View {
    let symbol: String
    let symbolColor: Color
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(symbolColor)

            Text(text)
                .font(.notely(.footnote, weight: .medium))
                .foregroundStyle(.primary.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct SnapshotMetricTile: View {
    let title: String
    let value: String
    let caption: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)

                Text(title.notelyLocalized)
                    .font(.notely(.caption, weight: .medium))
                    .foregroundStyle(NotelyTheme.secondaryText)
            }

            Text(value)
                .font(.notely(.subheadline, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.9))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(caption.notelyLocalized)
                .font(.notely(.caption2, weight: .medium))
                .foregroundStyle(NotelyTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(NotelyTheme.elevatedSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(NotelyTheme.surfaceBorder, lineWidth: 1)
                }
        }
    }
}

private struct CategoryBreakdownRow: View {
    let breakdown: JournalCategoryBreakdown
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: breakdown.category.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(breakdown.category.tint)
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(breakdown.category.tint.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(breakdown.category.title)
                        .font(.notely(.footnote, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.88))

                    Text("\(breakdown.entryCount)")
                        .font(.notely(.caption, weight: .medium))
                        .foregroundStyle(NotelyTheme.secondaryText)

                    Spacer()

                    Text("\(Int((breakdown.share * 100).rounded()))%")
                        .font(.notely(.caption, weight: .semibold))
                        .foregroundStyle(breakdown.category.tint)

                    Text(breakdown.total.formattedCurrency(code: currencyCode))
                        .font(.notely(.footnote, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.86))
                        .monospacedDigit()
                }

                ProgressView(value: min(max(breakdown.share, 0), 1))
                    .tint(breakdown.category.tint)
                    .scaleEffect(x: 1, y: 1.4, anchor: .center)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(NotelyTheme.elevatedSurface.opacity(0.75))
        }
    }
}

private struct EmptyCategoryBreakdownRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NotelyTheme.reviewTint)
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(NotelyTheme.reviewTint.opacity(0.12))
                }

            Text("No notes yet this month.".notelyLocalized)
                .font(.notely(.footnote, weight: .medium))
                .foregroundStyle(NotelyTheme.secondaryText)

            Spacer()
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(NotelyTheme.elevatedSurface.opacity(0.75))
        }
    }
}

#Preview {
    ZStack {
        NotelyTheme.background.ignoresSafeArea()
        VStack {
            Spacer()
            HomeSnapshotCard(
                insight: JournalInsight(
                    dayExpenseTotal: 810,
                    dayIncomeTotal: 0,
                    dayNetTotal: -810,
                    monthExpenseTotal: 2166,
                    monthIncomeTotal: 28000,
                    monthNetTotal: 25834,
                    topCategory: .food,
                    reviewCount: 2,
                    monthEntryCount: 8,
                    monthAveragePerEntry: 270.75,
                    topCategoryShare: 0.38,
                    categoryBreakdown: [
                        JournalCategoryBreakdown(
                            category: .food,
                            total: 822,
                            share: 0.38,
                            entryCount: 4
                        ),
                        JournalCategoryBreakdown(
                            category: .transport,
                            total: 650,
                            share: 0.30,
                            entryCount: 2
                        ),
                        JournalCategoryBreakdown(
                            category: .shopping,
                            total: 694,
                            share: 0.32,
                            entryCount: 2
                        )
                    ]
                ),
                currencyCode: "NOK"
            )
            HomeSummaryBar(
                insight: JournalInsight(
                    dayExpenseTotal: 810,
                    dayIncomeTotal: 0,
                    dayNetTotal: -810,
                    monthExpenseTotal: 2166,
                    monthIncomeTotal: 28000,
                    monthNetTotal: 25834,
                    topCategory: .food,
                    reviewCount: 2,
                    monthEntryCount: 8,
                    monthAveragePerEntry: 270.75,
                    topCategoryShare: 0.38,
                    categoryBreakdown: [
                        JournalCategoryBreakdown(
                            category: .food,
                            total: 822,
                            share: 0.38,
                            entryCount: 4
                        )
                    ]
                ),
                entryCount: 4,
                currencyCode: "NOK",
                onTap: {}
            )
        }
    }
}
