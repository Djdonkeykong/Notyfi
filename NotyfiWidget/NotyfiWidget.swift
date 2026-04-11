import SwiftUI
import WidgetKit

struct NotyfiWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: NotyfiFinanceSnapshot
}

struct NotyfiWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> NotyfiWidgetEntry {
        NotyfiWidgetEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (NotyfiWidgetEntry) -> Void) {
        completion(NotyfiWidgetEntry(date: .now, snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NotyfiWidgetEntry>) -> Void) {
        let entry = NotyfiWidgetEntry(date: .now, snapshot: loadSnapshot())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadSnapshot() -> NotyfiFinanceSnapshot {
        let defaults = NotyfiSharedStorage.sharedDefaults()
        guard
            let data = defaults.data(forKey: NotyfiSharedStorage.financeSnapshotKey),
            let snapshot = try? JSONDecoder().decode(NotyfiFinanceSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }
}

// MARK: - Entry View

struct NotyfiWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NotyfiWidgetProvider.Entry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(snapshot: entry.snapshot)
        case .accessoryRectangular:
            LockRectangularView(snapshot: entry.snapshot)
        case .accessoryCircular:
            LockCircularView(snapshot: entry.snapshot)
        case .accessoryInline:
            LockInlineView(snapshot: entry.snapshot)
        default:
            SmallWidgetView(snapshot: entry.snapshot)
        }
    }
}

// MARK: - Small Widget

private struct SmallWidgetView: View {
    let snapshot: NotyfiFinanceSnapshot

    private var spendAmount: String {
        snapshot.monthSpent.formattedCurrency(code: snapshot.currencyCode)
    }

    private var budgetProgress: Double {
        guard snapshot.hasBudget, snapshot.monthlyBudgetLimit > 0 else { return 0 }
        return min(snapshot.monthSpent / snapshot.monthlyBudgetLimit, 1.0)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Mascot peeking in from bottom-left
            Image("app-mascot-clean")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .shadow(color: .black.opacity(0.10), radius: 8, x: 2, y: -2)
                .offset(x: -22, y: 28)

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // Main number
                Text(spendAmount)
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .monospacedDigit()

                if let budget = budgetString {
                    Text("of \(budget)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.55))
                        .monospacedDigit()
                        .padding(.top, 1)
                }

                Text("spent this month".notyfiLocalized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)

                // Budget bar
                if snapshot.hasBudget {
                    WidgetProgressBar(progress: budgetProgress)
                        .frame(height: 4)
                        .padding(.top, 10)
                }

                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) {
            Color(red: 242/255, green: 242/255, blue: 249/255)
        }
    }

    private var budgetString: String? {
        guard snapshot.hasBudget else { return nil }
        return snapshot.monthlyBudgetLimit.formattedCurrency(code: snapshot.currencyCode)
    }
}

// MARK: - Medium Widget

private struct MediumWidgetView: View {
    let snapshot: NotyfiFinanceSnapshot

    private var spendAmount: String {
        snapshot.monthSpent.formattedCurrency(code: snapshot.currencyCode)
    }

    private var budgetString: String? {
        guard snapshot.hasBudget else { return nil }
        return snapshot.monthlyBudgetLimit.formattedCurrency(code: snapshot.currencyCode)
    }

    private var budgetProgress: Double {
        guard snapshot.hasBudget, snapshot.monthlyBudgetLimit > 0 else { return 0 }
        return min(snapshot.monthSpent / snapshot.monthlyBudgetLimit, 1.0)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Mascot — peeks in from the right like the app icon
            Image("app-mascot-clean")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .shadow(color: .black.opacity(0.10), radius: 10, x: -2, y: 4)
                .offset(x: 44, y: 10)  // pushed right so only left portion is visible

            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    // Big number
                    Text(spendAmount)
                        .font(.system(size: 36, weight: .bold, design: .default))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .monospacedDigit()

                    if let budget = budgetString {
                        Text("of \(budget)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.55))
                            .monospacedDigit()
                            .padding(.top, 2)
                    }

                    Text("spent this month".notyfiLocalized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)

                    // Stat row
                    HStack(spacing: 14) {
                        WidgetStatPill(
                            label: "Today".notyfiLocalized,
                            value: snapshot.todaySpent.formattedCurrency(code: snapshot.currencyCode)
                        )
                        if snapshot.hasBudget {
                            WidgetStatPill(
                                label: "Left".notyfiLocalized,
                                value: snapshot.budgetLeft.formattedCurrency(code: snapshot.currencyCode)
                            )
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .overlay(alignment: .bottom) {
            if snapshot.hasBudget {
                WidgetProgressBar(progress: budgetProgress)
                    .frame(height: 4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
        }
        .containerBackground(for: .widget) {
            Color(red: 242/255, green: 242/255, blue: 249/255)
        }
    }
}

// MARK: - Lock Screen: Rectangular

private struct LockRectangularView: View {
    let snapshot: NotyfiFinanceSnapshot

    private var daysLeftString: String {
        let calendar = Calendar.current
        let now = Date()
        guard let range = calendar.range(of: .day, in: .month, for: now) else { return "" }
        let remaining = max(0, range.count - calendar.component(.day, from: now))
        switch remaining {
        case 0:  return "widget.days.last".notyfiLocalized
        case 1:  return "widget.days.one".notyfiLocalized
        default: return String(format: "widget.days.many".notyfiLocalized, remaining)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("This month".notyfiLocalized)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Text(snapshot.monthSpent.formattedCurrency(code: snapshot.currencyCode))
                .font(.system(size: 18, weight: .bold, design: .default))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .monospacedDigit()
                .widgetAccentable()

            Text(daysLeftString)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Lock Screen: Circular

private struct LockCircularView: View {
    let snapshot: NotyfiFinanceSnapshot

    private var budgetProgress: Double {
        guard snapshot.hasBudget, snapshot.monthlyBudgetLimit > 0 else { return 0 }
        return min(snapshot.monthSpent / snapshot.monthlyBudgetLimit, 1.0)
    }

    var body: some View {
        Gauge(value: snapshot.hasBudget ? budgetProgress : 0) {
            EmptyView()
        } currentValueLabel: {
            VStack(spacing: 0) {
                Text(snapshot.monthSpent.formattedCurrency(code: snapshot.currencyCode))
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .monospacedDigit()
                Text(snapshot.currencyCode)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Lock Screen: Inline

private struct LockInlineView: View {
    let snapshot: NotyfiFinanceSnapshot

    var body: some View {
        if snapshot.hasBudget {
            Label {
                Text("\(snapshot.monthSpent.formattedCurrency(code: snapshot.currencyCode)) of \(snapshot.monthlyBudgetLimit.formattedCurrency(code: snapshot.currencyCode))")
                    .monospacedDigit()
            } icon: {
                Image(systemName: "flame.fill")
            }
        } else {
            Label {
                Text(snapshot.monthSpent.formattedCurrency(code: snapshot.currencyCode))
                    .monospacedDigit()
            } icon: {
                Image(systemName: "flame.fill")
            }
        }
    }
}

// MARK: - Shared Components

private struct WidgetProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.primary.opacity(0.1))
                Capsule()
                    .fill(.primary.opacity(0.55))
                    .frame(width: geo.size.width * max(0.03, progress))
            }
        }
    }
}

private struct WidgetStatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
    }
}

// MARK: - Widget

@main
struct NotyfiWidget: Widget {
    let kind = "NotyfiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NotyfiWidgetProvider()) { entry in
            NotyfiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Monthly Overview".notyfiLocalized)
        .description("See your monthly spend and budget at a glance.".notyfiLocalized)
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
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

#Preview("Medium", as: .systemMedium) {
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
