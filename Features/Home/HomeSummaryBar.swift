import SwiftUI

struct HomeSummaryBar: View {
    let insight: JournalInsight
    let entryCount: Int
    let currencyCode: String
    let animationNamespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            Haptics.mediumImpact()
            onTap()
        }) {
            SoftCapsule(horizontalPadding: 22, verticalPadding: 16) {
                HStack(spacing: 16) {
                    HomeTotalCounterPill(
                        totalText: insight.dayTotal.formattedCurrency(code: currencyCode),
                        horizontalPadding: 0,
                        minHeight: 28,
                        showsBackground: false
                    )
                    .matchedGeometryEffect(id: "homeTotalCounter", in: animationNamespace)

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
                .frame(minHeight: 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .buttonStyle(.plain)
    }
}

struct HomeTotalCounterPill: View {
    let totalText: String
    var horizontalPadding: CGFloat = 20
    var minHeight: CGFloat = 46
    var showsBackground = true

    var body: some View {
        HStack(spacing: 10) {
            Text("\u{1F525}")
                .font(.system(size: 17))

            Text(totalText)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.96))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, horizontalPadding)
        .frame(minHeight: minHeight)
        .background {
            if showsBackground {
                Capsule()
                    .fill(NotelyTheme.surface)
                    .overlay {
                        Capsule()
                            .stroke(NotelyTheme.surfaceBorder, lineWidth: 1)
                    }
                    .shadow(color: NotelyTheme.shadow, radius: 18, x: 0, y: 10)
            }
        }
    }
}

struct HomeSnapshotCard: View {
    let insight: JournalInsight
    let entryCount: Int
    let averageSpend: Double
    let currencyCode: String

    private var progressValue: Double {
        let denominator = max(insight.monthTotal, insight.dayTotal, 1)
        return min(insight.dayTotal / denominator, 1)
    }

    var body: some View {
        SoftSurface(cornerRadius: 34, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Snapshot")
                    .font(.notely(.headline, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.86))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Spend today", systemImage: "circle.fill")
                            .font(.notely(.footnote, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.82))

                        Spacer()

                        Text("\(insight.dayTotal.formattedCurrency(code: currencyCode)) / \(insight.monthTotal.formattedCurrency(code: currencyCode))")
                            .font(.notely(.footnote, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.84))
                            .monospacedDigit()
                    }

                    ProgressView(value: progressValue)
                        .tint(NotelyTheme.reviewTint)
                        .scaleEffect(x: 1, y: 1.6, anchor: .center)
                }

                HStack(spacing: 14) {
                    SnapshotMetricOrb(
                        value: "\(entryCount)",
                        label: "Notes",
                        tint: Color(red: 0.42, green: 0.73, blue: 0.47)
                    )

                    SnapshotMetricOrb(
                        value: "\(insight.reviewCount)",
                        label: "Review",
                        tint: Color(red: 0.88, green: 0.35, blue: 0.31)
                    )

                    SnapshotMetricOrb(
                        value: averageSpend.formattedCurrency(code: currencyCode),
                        label: "Average",
                        tint: Color(red: 0.42, green: 0.73, blue: 0.47)
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
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

private struct SnapshotMetricOrb: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.08), lineWidth: 4)
                    .frame(width: 68, height: 68)

                Circle()
                    .trim(from: 0.08, to: 0.82)
                    .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-110))
                    .frame(width: 68, height: 68)

                Text(value)
                    .font(.notely(.footnote, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.84))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                    .frame(width: 48)
            }

            Text(label)
                .font(.notely(.caption))
                .foregroundStyle(NotelyTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HomeSummaryBarPreviewWrapper: View {
    @Namespace private var animationNamespace

    var body: some View {
        ZStack {
            NotelyTheme.background.ignoresSafeArea()
            VStack {
                Spacer()
                HomeSnapshotCard(
                    insight: JournalInsight(
                        dayTotal: 810,
                        monthTotal: 2166,
                        topCategory: .food,
                        reviewCount: 2
                    ),
                    entryCount: 4,
                    averageSpend: 202.5,
                    currencyCode: "NOK"
                )
                HomeSummaryBar(
                    insight: JournalInsight(
                        dayTotal: 810,
                        monthTotal: 2166,
                        topCategory: .food,
                        reviewCount: 2
                    ),
                    entryCount: 4,
                    currencyCode: "NOK",
                    animationNamespace: animationNamespace,
                    onTap: {}
                )
            }
        }
    }
}

#Preview {
    HomeSummaryBarPreviewWrapper()
}
