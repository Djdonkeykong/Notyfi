import SwiftUI
import WidgetKit

struct NotyfiWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: NotyfiFinanceSnapshot
}

struct NotyfiWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> NotyfiWidgetEntry {
        NotyfiWidgetEntry(
            date: .now,
            snapshot: .empty
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NotyfiWidgetEntry) -> Void) {
        completion(
            NotyfiWidgetEntry(
                date: .now,
                snapshot: loadSnapshot()
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NotyfiWidgetEntry>) -> Void) {
        let entry = NotyfiWidgetEntry(
            date: .now,
            snapshot: loadSnapshot()
        )
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)

        completion(
            Timeline(
                entries: [entry],
                policy: .after(nextRefresh)
            )
        )
    }

    private func loadSnapshot() -> NotyfiFinanceSnapshot {
        let defaults = NotyfiSharedStorage.sharedDefaults()
        guard
            let data = defaults.data(forKey: NotyfiSharedStorage.financeSnapshotKey),
            let snapshot = try? JSONDecoder().decode(NotyfiFinanceSnapshot.self, from: data)
        else {
            return .empty
        }

        return snapshot
    }
}

struct NotyfiWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NotyfiWidgetProvider.Entry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notyfi")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            if entry.snapshot.hasBudget {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Left".notyfiLocalized)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(entry.snapshot.budgetLeft.formattedCurrency(code: entry.snapshot.currencyCode))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(entry.snapshot.budgetLeft >= 0 ? Color.green : Color.red)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                        .monospacedDigit()
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This month".notyfiLocalized)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(entry.snapshot.monthSpent.formattedCurrency(code: entry.snapshot.currencyCode))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                        .monospacedDigit()
                }
            }

            Divider()

            HStack(spacing: 8) {
                WidgetMetricColumn(
                    title: "Today",
                    value: entry.snapshot.todaySpent.formattedCurrency(code: entry.snapshot.currencyCode)
                )

                WidgetMetricColumn(
                    title: "Net",
                    value: signedCurrency(entry.snapshot.monthNet, currencyCode: entry.snapshot.currencyCode)
                )
            }
        }
        .padding(16)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Notyfi")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(entry.snapshot.generatedAt, style: .date)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                WidgetStatCard(
                    title: entry.snapshot.hasBudget ? "Left" : "Spend",
                    value: entry.snapshot.hasBudget
                        ? entry.snapshot.budgetLeft.formattedCurrency(code: entry.snapshot.currencyCode)
                        : entry.snapshot.monthSpent.formattedCurrency(code: entry.snapshot.currencyCode),
                    tint: entry.snapshot.hasBudget && entry.snapshot.budgetLeft < 0 ? Color.red : Color.blue
                )

                WidgetStatCard(
                    title: "Net",
                    value: signedCurrency(entry.snapshot.monthNet, currencyCode: entry.snapshot.currencyCode),
                    tint: entry.snapshot.monthNet >= 0 ? Color.green : Color.red
                )

                WidgetStatCard(
                    title: "Today",
                    value: entry.snapshot.todaySpent.formattedCurrency(code: entry.snapshot.currencyCode),
                    tint: Color.orange
                )
            }

            if !entry.snapshot.hasEntries {
                Text("Start logging in Notyfi to fill this widget.".notyfiLocalized)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func signedCurrency(_ amount: Double, currencyCode: String) -> String {
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

private struct WidgetMetricColumn: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.notyfiLocalized)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WidgetStatCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.notyfiLocalized)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.12))
        }
    }
}

@main
struct NotyfiWidget: Widget {
    let kind = "NotyfiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NotyfiWidgetProvider()) { entry in
            NotyfiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Notyfi overview".notyfiLocalized)
        .description("See your monthly spend, net, and today at a glance.".notyfiLocalized)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    NotyfiWidget()
} timeline: {
    NotyfiWidgetEntry(
        date: .now,
        snapshot: NotyfiFinanceSnapshot(
            generatedAt: .now,
            currencyCode: "NOK",
            todaySpent: 329,
            monthSpent: 12_880,
            monthIncome: 28_000,
            monthNet: 15_120,
            monthlyBudgetLimit: 15_000,
            budgetLeft: 2_120,
            hasBudget: true,
            hasEntries: true
        )
    )
}
