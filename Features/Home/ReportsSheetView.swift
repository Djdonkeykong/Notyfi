import SwiftUI
import Charts

struct ReportsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        ZStack {
            NotyfiTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    ReportsMetricHero(
                        title: "Reports",
                        subtitle: "See patterns in your spending without leaving home.",
                        amount: viewModel.insight.monthExpenseTotal.formattedCurrency(code: viewModel.currencyCode),
                        caption: monthCaption
                    )

                    SpendVsBudgetCard(
                        currencyCode: viewModel.currencyCode,
                        budgetLimit: viewModel.budgetPlan.monthlySpendingLimit,
                        currentSpend: viewModel.insight.monthExpenseTotal,
                        daysElapsed: viewModel.budgetInsight.daysElapsed,
                        daysInMonth: viewModel.budgetInsight.daysInMonth,
                        points: cumulativeExpenseSeries(for: viewModel.selectedDate)
                    )

                    MonthComparisonCard(
                        currencyCode: viewModel.currencyCode,
                        currentMonthLabel: monthShortLabel(for: viewModel.selectedDate),
                        previousMonthLabel: monthShortLabel(for: previousMonthAnchor),
                        currentPoints: cumulativeExpenseSeries(for: viewModel.selectedDate),
                        previousPoints: cumulativeExpenseSeries(for: previousMonthAnchor),
                        comparisonDay: viewModel.budgetInsight.daysElapsed
                    )

                    MonthlyTrendCard(
                        currencyCode: viewModel.currencyCode,
                        bars: recentMonthlySpendBars
                    )

                    RecurringLoadCard(
                        currencyCode: viewModel.currencyCode,
                        summary: recurringLoadSummary
                    )
                }
                .padding(.horizontal, 20)
                .safeAreaPadding(.top, 14)
                .padding(.bottom, 28)
            }
        }
    }
}

private extension ReportsSheetView {
    var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reports".notyfiLocalized)
                    .font(.notyfi(.title3, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.84))
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

    var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = NotyfiLocale.current()
        return calendar
    }

    var filteredEntries: [ExpenseEntry] {
        viewModel.allEntriesSnapshot.filter {
            $0.currencyCode.caseInsensitiveCompare(viewModel.currencyCode) == .orderedSame
        }
    }

    var previousMonthAnchor: Date {
        calendar.date(byAdding: .month, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
    }

    var monthCaption: String {
        let formatter = DateFormatter()
        formatter.locale = NotyfiLocale.current()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: viewModel.selectedDate)
    }

    func monthShortLabel(for date: Date) -> String {
        date.formatted(
            .dateTime
                .month(.abbreviated)
                .locale(NotyfiLocale.current())
        )
    }

    func cumulativeExpenseSeries(for monthAnchor: Date) -> [ReportLinePoint] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthAnchor) else {
            return []
        }

        let daysInMonth = calendar.range(of: .day, in: .month, for: monthInterval.start)?.count ?? 30
        let monthEntries = filteredEntries.filter {
            $0.transactionKind == .expense
                && calendar.isDate($0.date, equalTo: monthAnchor, toGranularity: .month)
        }

        let totalsByDay = Dictionary(grouping: monthEntries) { entry in
            calendar.component(.day, from: entry.date)
        }
        .mapValues { entries in
            entries.reduce(0) { $0 + $1.amount }
        }

        var runningTotal = 0.0
        return (1...daysInMonth).map { day in
            runningTotal += totalsByDay[day] ?? 0
            return ReportLinePoint(day: day, value: runningTotal)
        }
    }

    var recentMonthlySpendBars: [ReportBarPoint] {
        guard let currentMonthStart = calendar.dateInterval(of: .month, for: viewModel.selectedDate)?.start else {
            return []
        }

        return (0..<6).reversed().compactMap { reverseOffset in
            guard let monthStart = calendar.date(byAdding: .month, value: -reverseOffset, to: currentMonthStart) else {
                return nil
            }

            let total = filteredEntries
                .filter {
                    $0.transactionKind == .expense
                        && calendar.isDate($0.date, equalTo: monthStart, toGranularity: .month)
                }
                .reduce(0) { $0 + $1.amount }

            return ReportBarPoint(
                monthStart: monthStart,
                label: monthStart.formatted(
                    .dateTime
                        .month(.abbreviated)
                        .locale(NotyfiLocale.current())
                ),
                value: total
            )
        }
    }

    var recurringLoadSummary: RecurringLoadSummary {
        let activeExpenses = viewModel.recurringTransactionsSnapshot
            .filter {
                $0.isActive
                    && $0.transactionKind == .expense
                    && $0.currencyCode.caseInsensitiveCompare(viewModel.currencyCode) == .orderedSame
            }
            .sorted { lhs, rhs in
                lhs.nextOccurrenceAt < rhs.nextOccurrenceAt
            }

        let monthlyLoad = activeExpenses.reduce(0.0) { partialResult, transaction in
            partialResult + monthlyEquivalent(for: transaction)
        }

        let nextThirtyDays = Date().addingTimeInterval(30 * 24 * 60 * 60)
        let upcomingTransactions = activeExpenses
            .filter { $0.nextOccurrenceAt <= nextThirtyDays }
            .prefix(3)
            .map { transaction in
                RecurringPreview(
                    title: transaction.title,
                    amount: transaction.amount,
                    category: transaction.category,
                    schedule: transaction.scheduleSummary,
                    nextOccurrenceAt: transaction.nextOccurrenceAt
                )
            }

        return RecurringLoadSummary(
            monthlyLoad: monthlyLoad,
            activeRuleCount: activeExpenses.count,
            upcoming: Array(upcomingTransactions)
        )
    }

    func monthlyEquivalent(for transaction: RecurringTransaction) -> Double {
        let interval = max(1, transaction.interval)

        switch transaction.frequency {
        case .weekly:
            return transaction.amount * (52.0 / 12.0) / Double(interval)
        case .monthly:
            return transaction.amount / Double(interval)
        case .yearly:
            return transaction.amount / (12.0 * Double(interval))
        }
    }
}

private struct ReportsMetricHero: View {
    let title: String
    let subtitle: String
    let amount: String
    let caption: String

    var body: some View {
        SoftSurface(cornerRadius: 28, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                Text(title.notyfiLocalized)
                    .font(.notyfi(.headline, weight: .semibold))
                    .foregroundStyle(NotyfiTheme.primaryText)

                Text(subtitle.notyfiLocalized)
                    .font(.notyfi(.footnote))
                    .foregroundStyle(NotyfiTheme.secondaryText)

                HStack(alignment: .lastTextBaseline) {
                    Text(amount)
                        .font(.notyfi(.title2, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.84))

                    Spacer()

                    Text(caption)
                        .font(.notyfi(.footnote))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                }
            }
        }
    }
}

private struct SpendVsBudgetCard: View {
    let currencyCode: String
    let budgetLimit: Double
    let currentSpend: Double
    let daysElapsed: Int
    let daysInMonth: Int
    let points: [ReportLinePoint]

    private var budgetPacePoints: [ReportLinePoint] {
        guard budgetLimit > 0 else {
            return []
        }

        return points.map { point in
            ReportLinePoint(
                day: point.day,
                value: budgetLimit * (Double(point.day) / Double(max(daysInMonth, 1)))
            )
        }
    }

    private var takeaway: String {
        guard budgetLimit > 0 else {
            return "Set a monthly budget to unlock this chart.".notyfiLocalized
        }

        let paceSpend = budgetLimit * (Double(daysElapsed) / Double(max(daysInMonth, 1)))
        let delta = currentSpend - paceSpend

        if abs(delta) < 0.5 {
            return "Right on pace for this point in the month.".notyfiLocalized
        }

        if delta > 0 {
            return String(
                format: "%@ over your budget pace".notyfiLocalized,
                abs(delta).formattedCurrency(code: currencyCode)
            )
        }

        return String(
            format: "%@ under your budget pace".notyfiLocalized,
            abs(delta).formattedCurrency(code: currencyCode)
        )
    }

    private var maxValue: Double {
        max(
            points.map(\.value).max() ?? 0,
            budgetPacePoints.map(\.value).max() ?? 0,
            budgetLimit,
            1
        )
    }

    var body: some View {
        ReportCard(
            title: "Spend vs budget pace",
            subtitle: takeaway
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ReportLegendRow(items: [
                    ReportLegendItem(title: "Spent".notyfiLocalized, color: NotyfiTheme.expenseColor, style: .solid),
                    ReportLegendItem(title: "Budget pace".notyfiLocalized, color: NotyfiTheme.brandBlue, style: .dashed)
                ])

                if budgetLimit > 0 {
                    Chart {
                        ForEach(points) { point in
                            LineMark(
                                x: .value("Day".notyfiLocalized, point.day),
                                y: .value("Spent".notyfiLocalized, point.value)
                            )
                            .foregroundStyle(NotyfiTheme.expenseColor)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        }

                        ForEach(budgetPacePoints) { point in
                            LineMark(
                                x: .value("Day".notyfiLocalized, point.day),
                                y: .value("Budget pace".notyfiLocalized, point.value)
                            )
                            .foregroundStyle(NotyfiTheme.brandBlue)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        }
                    }
                    .chartYScale(domain: 0...maxValue * 1.08)
                    .chartXAxis {
                        AxisMarks(values: strideValues(upTo: max(points.last?.day ?? 1, 1))) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(NotyfiTheme.surfaceBorder)
                            AxisValueLabel {
                                if let day = value.as(Int.self) {
                                    Text("\(day)")
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(NotyfiTheme.surfaceBorder)
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(amount.axisCurrency(code: currencyCode))
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                } else {
                    ReportEmptyState(message: "Set a monthly budget to unlock this chart.")
                }
            }
        }
    }
}

private struct MonthComparisonCard: View {
    let currencyCode: String
    let currentMonthLabel: String
    let previousMonthLabel: String
    let currentPoints: [ReportLinePoint]
    let previousPoints: [ReportLinePoint]
    let comparisonDay: Int

    private var maxValue: Double {
        max(
            currentPoints.map(\.value).max() ?? 0,
            previousPoints.map(\.value).max() ?? 0,
            1
        )
    }

    private var takeaway: String {
        guard !currentPoints.isEmpty || !previousPoints.isEmpty else {
            return "No month-to-month comparison yet.".notyfiLocalized
        }

        let currentValue = currentPoints[valueAt: comparisonDay] ?? 0
        let previousValue = previousPoints[valueAt: comparisonDay] ?? 0
        let delta = currentValue - previousValue

        if abs(delta) < 0.5 {
            return "Almost identical to the same point last month.".notyfiLocalized
        }

        if delta > 0 {
            return String(
                format: "%@ higher than the same point last month".notyfiLocalized,
                abs(delta).formattedCurrency(code: currencyCode)
            )
        }

        return String(
            format: "%@ lower than the same point last month".notyfiLocalized,
            abs(delta).formattedCurrency(code: currencyCode)
        )
    }

    var body: some View {
        ReportCard(
            title: "This month vs last month",
            subtitle: takeaway
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ReportLegendRow(items: [
                    ReportLegendItem(title: currentMonthLabel, color: NotyfiTheme.brandBlue, style: .solid),
                    ReportLegendItem(title: previousMonthLabel, color: NotyfiTheme.secondaryText, style: .solid)
                ])

                if !currentPoints.isEmpty || !previousPoints.isEmpty {
                    Chart {
                        ForEach(previousPoints) { point in
                            LineMark(
                                x: .value("Day".notyfiLocalized, point.day),
                                y: .value("Last month".notyfiLocalized, point.value)
                            )
                            .foregroundStyle(NotyfiTheme.secondaryText)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                            .opacity(0.9)
                        }

                        ForEach(currentPoints) { point in
                            LineMark(
                                x: .value("Day".notyfiLocalized, point.day),
                                y: .value("This month".notyfiLocalized, point.value)
                            )
                            .foregroundStyle(NotyfiTheme.brandBlue)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        }
                    }
                    .chartYScale(domain: 0...maxValue * 1.08)
                    .chartXAxis {
                        AxisMarks(values: strideValues(upTo: max(currentPoints.last?.day ?? 1, previousPoints.last?.day ?? 1))) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(NotyfiTheme.surfaceBorder)
                            AxisValueLabel {
                                if let day = value.as(Int.self) {
                                    Text("\(day)")
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(NotyfiTheme.surfaceBorder)
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(amount.axisCurrency(code: currencyCode))
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                } else {
                    ReportEmptyState(message: "No month-to-month comparison yet.")
                }
            }
        }
    }
}

private struct MonthlyTrendCard: View {
    let currencyCode: String
    let bars: [ReportBarPoint]

    private var averageSpend: Double {
        guard !bars.isEmpty else {
            return 0
        }

        return bars.reduce(0) { $0 + $1.value } / Double(bars.count)
    }

    private var takeaway: String {
        guard bars.contains(where: { $0.value > 0 }) else {
            return "Add a few entries to start seeing spending trends.".notyfiLocalized
        }

        return String(
            format: "Average %@ across the last 6 months".notyfiLocalized,
            averageSpend.formattedCurrency(code: currencyCode)
        )
    }

    private var maxValue: Double {
        max(bars.map(\.value).max() ?? 0, 1)
    }

    var body: some View {
        ReportCard(
            title: "Last 6 months",
            subtitle: takeaway
        ) {
            if bars.contains(where: { $0.value > 0 }) {
                Chart(bars) { bar in
                    BarMark(
                        x: .value("Month".notyfiLocalized, bar.label),
                        y: .value("Spent".notyfiLocalized, bar.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                NotyfiTheme.brandBlue.opacity(0.88),
                                NotyfiTheme.brandBlue.opacity(0.58)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYScale(domain: 0...maxValue * 1.12)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(NotyfiTheme.surfaceBorder)
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(amount.axisCurrency(code: currencyCode))
                            }
                        }
                    }
                }
                .frame(height: 200)
            } else {
                ReportEmptyState(message: "Add a few entries to start seeing spending trends.")
            }
        }
    }
}

private struct RecurringLoadCard: View {
    let currencyCode: String
    let summary: RecurringLoadSummary

    private var monthlyLoadText: String {
        summary.monthlyLoad.formattedCurrency(code: currencyCode)
    }

    private var rulesText: String {
        String(
            format: "%d active recurring rules".notyfiLocalized,
            summary.activeRuleCount
        )
    }

    var body: some View {
        ReportCard(
            title: "Recurring load",
            subtitle: summary.activeRuleCount > 0
                ? rulesText
                : "No recurring rules yet.".notyfiLocalized
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    RecurringMetricPill(
                        title: "Monthly load",
                        value: monthlyLoadText,
                        tint: NotyfiTheme.brandBlue
                    )

                    RecurringMetricPill(
                        title: "Upcoming",
                        value: "\(summary.upcoming.count)",
                        tint: NotyfiTheme.expenseColor
                    )
                }

                if summary.upcoming.isEmpty {
                    ReportEmptyState(message: "No recurring rules yet.")
                } else {
                    VStack(spacing: 10) {
                        ForEach(summary.upcoming) { transaction in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(transaction.category.tint.opacity(0.14))
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        Image(systemName: "repeat")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(transaction.category.tint)
                                    }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(transaction.title)
                                        .font(.notyfi(.subheadline, weight: .semibold))
                                        .foregroundStyle(.primary.opacity(0.82))
                                        .lineLimit(1)

                                    Text(transaction.nextOccurrenceAt.formatted(
                                        .dateTime
                                            .month(.abbreviated)
                                            .day()
                                            .locale(NotyfiLocale.current())
                                    ))
                                    .font(.notyfi(.caption))
                                    .foregroundStyle(NotyfiTheme.secondaryText)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(transaction.amount.formattedCurrency(code: currencyCode))
                                        .font(.notyfi(.subheadline, weight: .semibold))
                                        .foregroundStyle(NotyfiTheme.primaryText)

                                    Text(transaction.schedule)
                                        .font(.notyfi(.caption))
                                        .foregroundStyle(NotyfiTheme.secondaryText)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct RecurringMetricPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.notyfiLocalized)
                .font(.notyfi(.caption, weight: .medium))
                .foregroundStyle(NotyfiTheme.secondaryText)

            Text(value)
                .font(.notyfi(.headline, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.84))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(tint.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(tint.opacity(0.12), lineWidth: 1)
                }
        }
    }
}

private struct ReportCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        SoftSurface(cornerRadius: 28, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title.notyfiLocalized)
                        .font(.notyfi(.headline, weight: .semibold))
                        .foregroundStyle(NotyfiTheme.primaryText)

                    Text(subtitle.notyfiLocalized)
                        .font(.notyfi(.footnote))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                }

                content()
            }
        }
    }
}

private struct ReportLegendRow: View {
    let items: [ReportLegendItem]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(items) { item in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(item.color)
                        .frame(width: 16, height: 3)
                        .overlay {
                            if item.style == .dashed {
                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                                    .foregroundStyle(item.color)
                            }
                        }

                    Text(item.title)
                        .font(.notyfi(.caption))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                }
            }
        }
    }
}

private struct ReportEmptyState: View {
    let message: String

    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(NotyfiTheme.inputSurface)
            .frame(height: 154)
            .overlay {
                Text(message.notyfiLocalized)
                    .font(.notyfi(.footnote))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
    }
}

private struct ReportLinePoint: Identifiable {
    let day: Int
    let value: Double

    var id: Int {
        day
    }
}

private struct ReportBarPoint: Identifiable {
    let monthStart: Date
    let label: String
    let value: Double

    var id: Date {
        monthStart
    }
}

private struct RecurringLoadSummary {
    let monthlyLoad: Double
    let activeRuleCount: Int
    let upcoming: [RecurringPreview]
}

private struct RecurringPreview: Identifiable {
    let title: String
    let amount: Double
    let category: ExpenseCategory
    let schedule: String
    let nextOccurrenceAt: Date

    var id: String {
        "\(title)|\(nextOccurrenceAt.timeIntervalSinceReferenceDate)"
    }
}

private struct ReportLegendItem: Identifiable {
    enum LineStyle {
        case solid
        case dashed
    }

    let title: String
    let color: Color
    let style: LineStyle

    var id: String {
        title
    }
}

private func strideValues(upTo count: Int) -> [Int] {
    let safeCount = max(count, 1)
    let step = max(1, safeCount / 4)
    var values = Array(stride(from: 1, through: safeCount, by: step))

    if values.last != safeCount {
        values.append(safeCount)
    }

    return values
}

private extension Array where Element == ReportLinePoint {
    subscript(valueAt day: Int) -> Double? {
        guard !isEmpty else {
            return nil
        }

        let safeIndex = Swift.max(0, Swift.min(day - 1, count - 1))
        return self[safeIndex].value
    }
}

private extension Double {
    func axisCurrency(code: String) -> String {
        if self <= 0 {
            return "0"
        }

        let absolute = abs(self)
        let scaledAmount: Double
        let suffix: String

        switch absolute {
        case 1_000_000...:
            scaledAmount = self / 1_000_000
            suffix = "M"
        case 1_000...:
            scaledAmount = self / 1_000
            suffix = "k"
        default:
            return formattedCurrency(code: code)
        }

        return "\(scaledAmount.formatted(.number.precision(.fractionLength(absolute >= 10_000 ? 0 : 1))))\(suffix)"
    }
}

#Preview {
    ReportsSheetView(viewModel: HomeViewModel(store: ExpenseJournalStore(previewMode: true)))
}
