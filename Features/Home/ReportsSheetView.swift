import SwiftUI
import Charts

struct ReportsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HomeViewModel

    @State private var reportMonth: Date = Date()
    @State private var insightsResults: [String: InsightsResult] = [:]
    @State private var insightsLoadingKey: String? = nil

    private let insightsService = SpendingInsightsService()

    var body: some View {
        ZStack {
            NotyfiTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    let key = insightCacheKey(for: reportMonth)
                    let hasData = !categoryBreakdown(for: reportMonth).isEmpty

                    CategoryDonutCard(
                        currencyCode: viewModel.currencyCode,
                        breakdown: categoryBreakdown(for: reportMonth),
                        totalSpend: monthExpenseTotal(for: reportMonth),
                        monthLabel: monthLabel(for: reportMonth),
                        isCurrentMonth: calendar.isDate(reportMonth, equalTo: Date(), toGranularity: .month),
                        onPrevious: {
                            reportMonth = calendar.date(byAdding: .month, value: -1, to: reportMonth) ?? reportMonth
                        },
                        onNext: {
                            reportMonth = calendar.date(byAdding: .month, value: 1, to: reportMonth) ?? reportMonth
                        }
                    )

                    if hasData {
                        MonthlyNarrativeCard(
                            narrative: insightsResults[key]?.narrative,
                            isLoading: insightsLoadingKey == key,
                            monthLabel: monthLabel(for: reportMonth)
                        )
                    }

                    MonthlySpendCard(
                        currencyCode: viewModel.currencyCode,
                        budgetLimit: viewModel.budgetPlan.monthlySpendingLimit,
                        currentMonthLabel: monthShortLabel(for: reportMonth),
                        previousMonthLabel: monthShortLabel(for: previousMonth),
                        currentPoints: cumulativeExpenseSeries(for: reportMonth),
                        previousPoints: cumulativeExpenseSeries(for: previousMonth),
                        daysElapsed: daysElapsed(for: reportMonth),
                        daysInMonth: daysInMonth(for: reportMonth),
                        currentSpend: monthExpenseTotal(for: reportMonth)
                    )

                    MonthlyTrendCard(
                        currencyCode: viewModel.currencyCode,
                        bars: recentMonthlySpendBars(relativeTo: Date())
                    )

                    RecurringLoadCard(
                        currencyCode: viewModel.currencyCode,
                        summary: recurringLoadSummary
                    )

                    if hasData {
                        SpendingInsightsCard(
                            insights: insightsResults[key]?.insights ?? [],
                            isLoading: insightsLoadingKey == key,
                            monthLabel: monthLabel(for: reportMonth)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .safeAreaPadding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .task(id: insightCacheKey(for: reportMonth)) {
            await loadInsights(for: reportMonth)
        }
    }
}

// MARK: - Helpers

private extension ReportsSheetView {
    var header: some View {
        HStack(alignment: .top) {
            Text("Reports".notyfiLocalized)
                .font(.notyfi(.title3, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.84))

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .frame(width: 38, height: 38)
                    .background { Circle().fill(NotyfiTheme.elevatedSurface) }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 22)
    }

    var calendar: Calendar {
        var cal = Calendar.autoupdatingCurrent
        cal.locale = NotyfiLocale.current()
        return cal
    }

    var filteredEntries: [ExpenseEntry] {
        viewModel.allEntriesSnapshot.filter {
            $0.currencyCode.caseInsensitiveCompare(viewModel.currencyCode) == .orderedSame
        }
    }

    var previousMonth: Date {
        calendar.date(byAdding: .month, value: -1, to: reportMonth) ?? reportMonth
    }

    func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = NotyfiLocale.current()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date)
    }

    func monthShortLabel(for date: Date) -> String {
        date.formatted(
            .dateTime
                .month(.abbreviated)
                .locale(NotyfiLocale.current())
        )
    }

    func monthExpenseTotal(for date: Date) -> Double {
        filteredEntries
            .filter {
                $0.transactionKind == .expense
                    && calendar.isDate($0.date, equalTo: date, toGranularity: .month)
            }
            .reduce(0) { $0 + $1.amount }
    }

    func daysInMonth(for date: Date) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    func daysElapsed(for date: Date) -> Int {
        if calendar.isDate(date, equalTo: Date(), toGranularity: .month) {
            return calendar.component(.day, from: Date())
        }
        return daysInMonth(for: date)
    }

    func categoryBreakdown(for date: Date) -> [JournalCategoryBreakdown] {
        let monthEntries = filteredEntries.filter {
            $0.transactionKind == .expense
                && calendar.isDate($0.date, equalTo: date, toGranularity: .month)
        }
        let total = monthEntries.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return [] }

        return Dictionary(grouping: monthEntries) { $0.category }
            .filter { $0.key != .uncategorized }
            .map { category, entries in
                let categoryTotal = entries.reduce(0) { $0 + $1.amount }
                return JournalCategoryBreakdown(
                    category: category,
                    total: categoryTotal,
                    share: categoryTotal / total,
                    entryCount: entries.count
                )
            }
            .sorted { $0.total > $1.total }
    }

    func cumulativeExpenseSeries(for monthAnchor: Date) -> [ReportLinePoint] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthAnchor) else {
            return []
        }

        let days = calendar.range(of: .day, in: .month, for: monthInterval.start)?.count ?? 30
        let monthEntries = filteredEntries.filter {
            $0.transactionKind == .expense
                && calendar.isDate($0.date, equalTo: monthAnchor, toGranularity: .month)
        }

        guard !monthEntries.isEmpty else { return [] }

        let totalsByDay = Dictionary(grouping: monthEntries) {
            calendar.component(.day, from: $0.date)
        }
        .mapValues { $0.reduce(0) { $0 + $1.amount } }

        var running = 0.0
        return (1...days).map { day in
            running += totalsByDay[day] ?? 0
            return ReportLinePoint(day: day, value: running)
        }
    }

    func recentMonthlySpendBars(relativeTo anchor: Date) -> [ReportBarPoint] {
        guard let anchorStart = calendar.dateInterval(of: .month, for: anchor)?.start else {
            return []
        }

        return (0..<6).reversed().compactMap { offset in
            guard let monthStart = calendar.date(byAdding: .month, value: -offset, to: anchorStart) else {
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
                    .dateTime.month(.abbreviated).locale(NotyfiLocale.current())
                ),
                value: total
            )
        }
    }

    var recurringLoadSummary: RecurringLoadSummary {
        let active = viewModel.recurringTransactionsSnapshot
            .filter {
                $0.isActive
                    && $0.transactionKind == .expense
                    && $0.currencyCode.caseInsensitiveCompare(viewModel.currencyCode) == .orderedSame
            }
            .sorted { $0.nextOccurrenceAt < $1.nextOccurrenceAt }

        let monthlyLoad = active.reduce(0.0) { $0 + monthlyEquivalent(for: $1) }
        let upcoming = active
            .filter { $0.nextOccurrenceAt <= Date().addingTimeInterval(30 * 24 * 60 * 60) }
            .prefix(3)
            .map {
                RecurringPreview(
                    title: $0.title,
                    amount: $0.amount,
                    category: $0.category,
                    schedule: $0.scheduleSummary,
                    nextOccurrenceAt: $0.nextOccurrenceAt
                )
            }

        return RecurringLoadSummary(
            monthlyLoad: monthlyLoad,
            activeRuleCount: active.count,
            upcoming: Array(upcoming)
        )
    }

    func monthlyEquivalent(for transaction: RecurringTransaction) -> Double {
        let interval = max(1, transaction.interval)
        switch transaction.frequency {
        case .weekly:  return transaction.amount * (52.0 / 12.0) / Double(interval)
        case .monthly: return transaction.amount / Double(interval)
        case .yearly:  return transaction.amount / (12.0 * Double(interval))
        }
    }

    func insightCacheKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let yearMonth = "\(components.year ?? 0)-\(components.month ?? 0)"
        let breakdown = categoryBreakdown(for: date)
        let bucketedTotal = Int(monthExpenseTotal(for: date) / 100) * 100
        return "\(yearMonth).\(viewModel.currencyCode).\(bucketedTotal).\(breakdown.count)"
    }

    func loadInsights(for month: Date) async {
        let key = insightCacheKey(for: month)

        if insightsResults[key] != nil { return }

        if let cached = loadCachedInsights(key: key) {
            insightsResults[key] = cached
            return
        }

        let breakdown = categoryBreakdown(for: month)
        guard !breakdown.isEmpty else { return }

        insightsLoadingKey = key

        let prevExpenseTotal = monthExpenseTotal(for: calendar.date(byAdding: .month, value: -1, to: month) ?? month)
        let monthEntries = filteredEntries.filter {
            calendar.isDate($0.date, equalTo: month, toGranularity: .month)
        }
        let incomeTotal = monthEntries
            .filter { $0.transactionKind == .income }
            .reduce(0) { $0 + $1.amount }
        let topMerchants = Array(
            Dictionary(grouping: monthEntries.filter { $0.transactionKind == .expense }) { $0.merchant ?? "" }
                .filter { !$0.key.isEmpty }
                .sorted { $0.value.count > $1.value.count }
                .prefix(5)
                .map(\.key)
        )
        let categoryTotals = breakdown.map {
            SpendingInsightsService.CategoryTotal(
                category: $0.category.rawValue,
                total: $0.total,
                entryCount: $0.entryCount
            )
        }

        do {
            let result = try await insightsService.generate(
                monthLabel: monthLabel(for: month),
                currencyCode: viewModel.currencyCode,
                expenseTotal: monthExpenseTotal(for: month),
                incomeTotal: incomeTotal,
                budgetLimit: viewModel.budgetPlan.monthlySpendingLimit,
                categoryTotals: categoryTotals,
                previousMonthExpenseTotal: prevExpenseTotal,
                topMerchants: topMerchants
            )
            insightsResults[key] = result
            saveCachedInsights(result, key: key)
            let isCurrentMonth = calendar.isDate(month, equalTo: Date(), toGranularity: .month)
            if isCurrentMonth {
                viewModel.markInsightsGenerated(forMonthKey: key)
            }
        } catch {
            // Silently ignore — cards stay hidden on failure
        }

        if insightsLoadingKey == key {
            insightsLoadingKey = nil
        }
    }

    private func loadCachedInsights(key: String) -> InsightsResult? {
        guard let data = UserDefaults.standard.data(forKey: "notyfi.insights.\(key)"),
              let decoded = try? JSONDecoder().decode(InsightsResult.self, from: data) else {
            return nil
        }
        return decoded
    }

    private func saveCachedInsights(_ result: InsightsResult, key: String) {
        guard let data = try? JSONEncoder().encode(result) else { return }
        UserDefaults.standard.set(data, forKey: "notyfi.insights.\(key)")
    }
}

// MARK: - Category Donut Card

private struct CategoryDonutCard: View {
    let currencyCode: String
    let breakdown: [JournalCategoryBreakdown]
    let totalSpend: Double
    let monthLabel: String
    let isCurrentMonth: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        SoftSurface(cornerRadius: 28, padding: 18) {
            VStack(spacing: 0) {
                monthNavigator
                    .padding(.bottom, 22)

                donutChart
                    .padding(.bottom, 22)

                if !breakdown.isEmpty {
                    Divider()

                    categoryGrid
                        .padding(.top, 14)
                } else {
                    emptyState
                }
            }
        }
    }

    private var monthNavigator: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .frame(width: 32, height: 32)
                    .background { Circle().fill(NotyfiTheme.elevatedSurface) }
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthLabel)
                .font(.notyfi(.subheadline, weight: .semibold))
                .foregroundStyle(NotyfiTheme.primaryText)
                .animation(.none, value: monthLabel)

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isCurrentMonth ? NotyfiTheme.tertiaryText : NotyfiTheme.secondaryText)
                    .frame(width: 32, height: 32)
                    .background { Circle().fill(NotyfiTheme.elevatedSurface) }
            }
            .disabled(isCurrentMonth)
            .buttonStyle(.plain)
        }
    }

    private var donutChart: some View {
        ZStack {
            if breakdown.isEmpty {
                Circle()
                    .stroke(NotyfiTheme.inputSurface, lineWidth: 26)
                    .frame(width: 190, height: 190)
            } else {
                Chart(breakdown) { item in
                    SectorMark(
                        angle: .value("Amount", item.total),
                        innerRadius: .ratio(0.62),
                        angularInset: 2.0
                    )
                    .foregroundStyle(item.category.tint)
                    .cornerRadius(5)
                }
                .frame(width: 190, height: 190)
                .animation(.easeInOut(duration: 0.35), value: breakdown.map(\.total))
            }

            VStack(spacing: 4) {
                Text("Spent".notyfiLocalized)
                    .font(.notyfi(.caption))
                    .foregroundStyle(NotyfiTheme.secondaryText)

                Text(totalSpend.formattedCurrency(code: currencyCode))
                    .font(.notyfi(.title3, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.84))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .frame(maxWidth: 108)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var categoryGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 8
        ) {
            ForEach(breakdown, id: \.id) { item in
                CategoryDonutGridCell(item: item, currencyCode: currencyCode)
            }
        }
        .transaction { $0.animation = nil }
    }

    private var emptyState: some View {
        Text("No expenses logged this month.".notyfiLocalized)
            .font(.notyfi(.footnote))
            .foregroundStyle(NotyfiTheme.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }
}

private struct CategoryDonutGridCell: View {
    let item: JournalCategoryBreakdown
    let currencyCode: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(item.category.tint.opacity(0.14))
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: item.category.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(item.category.tint)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.category.title)
                    .font(.notyfi(.caption, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.82))
                    .lineLimit(1)

                Text(item.total.formattedCurrency(code: currencyCode))
                    .font(.notyfi(.caption2, weight: .medium))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            Text("\(Int((item.share * 100).rounded()))%")
                .font(.notyfi(.caption2, weight: .semibold))
                .foregroundStyle(item.category.tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(item.category.tint.opacity(0.07))
        }
    }
}

// MARK: - Monthly Spend Card

private struct MonthlySpendCard: View {
    let currencyCode: String
    let budgetLimit: Double
    let currentMonthLabel: String
    let previousMonthLabel: String
    let currentPoints: [ReportLinePoint]
    let previousPoints: [ReportLinePoint]
    let daysElapsed: Int
    let daysInMonth: Int
    let currentSpend: Double

    private var budgetPacePoints: [ReportLinePoint] {
        guard budgetLimit > 0 else { return [] }
        let days = max(daysInMonth, 1)
        return (1...days).map { day in
            ReportLinePoint(day: day, value: budgetLimit * Double(day) / Double(days))
        }
    }

    private var hasData: Bool {
        currentPoints.contains { $0.value > 0 } || previousPoints.contains { $0.value > 0 }
    }

    private var maxValue: Double {
        max(
            currentPoints.map(\.value).max() ?? 0,
            previousPoints.map(\.value).max() ?? 0,
            budgetLimit,
            1
        )
    }

    private var takeaway: String {
        guard hasData else {
            return "Add a few entries to start seeing spending trends.".notyfiLocalized
        }
        if budgetLimit > 0 {
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
        let currentValue = currentPoints[valueAt: daysElapsed] ?? 0
        let previousValue = previousPoints[valueAt: daysElapsed] ?? 0
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

    private var legendItems: [ReportLegendItem] {
        var items = [
            ReportLegendItem(title: currentMonthLabel, color: NotyfiTheme.brandBlue, style: .solid),
            ReportLegendItem(title: previousMonthLabel, color: NotyfiTheme.secondaryText, style: .solid)
        ]
        if budgetLimit > 0 {
            items.append(ReportLegendItem(
                title: "Budget pace".notyfiLocalized,
                color: NotyfiTheme.expenseColor,
                style: .dashed
            ))
        }
        return items
    }

    var body: some View {
        ReportCard(title: "Monthly spend", subtitle: takeaway) {
            VStack(alignment: .leading, spacing: 12) {
                ReportLegendRow(items: legendItems)

                if hasData {
                    Chart {
                        ForEach(previousPoints) { point in
                            LineMark(
                                x: .value("Day".notyfiLocalized, point.day),
                                y: .value("Last month".notyfiLocalized, point.value)
                            )
                            .foregroundStyle(NotyfiTheme.secondaryText.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        }
                        ForEach(currentPoints) { point in
                            LineMark(
                                x: .value("Day".notyfiLocalized, point.day),
                                y: .value("This month".notyfiLocalized, point.value)
                            )
                            .foregroundStyle(NotyfiTheme.brandBlue)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        }
                        ForEach(budgetPacePoints) { point in
                            LineMark(
                                x: .value("Day".notyfiLocalized, point.day),
                                y: .value("Budget pace".notyfiLocalized, point.value)
                            )
                            .foregroundStyle(NotyfiTheme.expenseColor.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        }
                    }
                    .chartYScale(domain: 0...maxValue * 1.08)
                    .chartXAxis {
                        AxisMarks(values: strideValues(upTo: max(
                            currentPoints.last?.day ?? 1,
                            previousPoints.last?.day ?? 1,
                            1
                        ))) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(NotyfiTheme.surfaceBorder)
                            AxisValueLabel {
                                if let day = value.as(Int.self) { Text("\(day)") }
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
                    ReportEmptyState(message: "Add a few entries to start seeing spending trends.")
                }
            }
        }
    }
}

// MARK: - Monthly Trend Card

private struct MonthlyTrendCard: View {
    let currencyCode: String
    let bars: [ReportBarPoint]

    private var averageSpend: Double {
        guard !bars.isEmpty else { return 0 }
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

    private var maxValue: Double { max(bars.map(\.value).max() ?? 0, 1) }

    var body: some View {
        ReportCard(title: "Last 6 months", subtitle: takeaway) {
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
                .chartXAxis { AxisMarks { _ in AxisValueLabel() } }
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

// MARK: - Recurring Load Card

private struct RecurringLoadCard: View {
    let currencyCode: String
    let summary: RecurringLoadSummary

    var body: some View {
        ReportCard(
            title: "Recurring load",
            subtitle: summary.activeRuleCount > 0
                ? String(format: "%d active recurring rules".notyfiLocalized, summary.activeRuleCount)
                : "No recurring rules yet.".notyfiLocalized
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    RecurringMetricPill(
                        title: "Monthly load",
                        value: summary.monthlyLoad.formattedCurrency(code: currencyCode),
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
                                        .foregroundStyle(NotyfiTheme.expenseColor)

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
                .font(.notyfi(.caption, weight: .semibold))
                .foregroundStyle(tint.opacity(0.7))

            Text(value)
                .font(.notyfi(.headline, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(tint.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(tint.opacity(0.22), lineWidth: 1)
                }
        }
    }
}

// MARK: - Monthly Narrative Card

private struct MonthlyNarrativeCard: View {
    let narrative: String?
    let isLoading: Bool
    let monthLabel: String

    var body: some View {
        if narrative != nil {
            SoftSurface(cornerRadius: 28, padding: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("Monthly summary".notyfiLocalized)
                            .font(.notyfi(.subheadline, weight: .semibold))
                            .foregroundStyle(NotyfiTheme.primaryText)

                        Spacer(minLength: 0)

                        Text("AI")
                            .font(.notyfi(.caption2, weight: .bold))
                            .foregroundStyle(NotyfiTheme.brandBlue)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(NotyfiTheme.brandBlue.opacity(0.12))
                            }
                    }

                    if isLoading {
                        HStack(spacing: 10) {
                            ProgressView().scaleEffect(0.8)
                            Text("Analysing your month...".notyfiLocalized)
                                .font(.notyfi(.footnote))
                                .foregroundStyle(NotyfiTheme.secondaryText)
                        }
                    } else if let narrative {
                        Text(narrative)
                            .font(.notyfi(.subheadline))
                            .foregroundStyle(.primary.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                    }
                }
            }
        }
    }
}

// MARK: - Spending Insights Card

private struct SpendingInsightsCard: View {
    let insights: [SpendingInsight]
    let isLoading: Bool
    let monthLabel: String

    var body: some View {
        if !insights.isEmpty {
            ReportCard(title: "Spending insights", subtitle: monthLabel) {
                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Analysing your month...".notyfiLocalized)
                            .font(.notyfi(.footnote))
                            .foregroundStyle(NotyfiTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                } else {
                    VStack(spacing: 12) {
                        ForEach(insights) { insight in
                            InsightRow(insight: insight)
                        }
                    }
                }
            }
        }
    }
}

private struct InsightRow: View {
    let insight: SpendingInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(tint)
                .frame(width: 3)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.headline)
                    .font(.notyfi(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.84))

                Text(insight.body)
                    .font(.notyfi(.footnote))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.06))
        }
    }

    private var tint: Color {
        switch insight.tag {
        case .overspending:      return NotyfiTheme.expenseColor
        case .savingOpportunity: return NotyfiTheme.brandBlue
        case .pattern:           return NotyfiTheme.secondaryText
        case .positive:          return NotyfiTheme.incomeColor
        }
    }
}

// MARK: - Shared Components

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

                    Text(subtitle)
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

// MARK: - Data Models

private struct ReportLinePoint: Identifiable {
    let day: Int
    let value: Double
    var id: Int { day }
}

private struct ReportBarPoint: Identifiable {
    let monthStart: Date
    let label: String
    let value: Double
    var id: Date { monthStart }
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
    var id: String { "\(title)|\(nextOccurrenceAt.timeIntervalSinceReferenceDate)" }
}

private struct ReportLegendItem: Identifiable {
    enum LineStyle { case solid, dashed }
    let title: String
    let color: Color
    let style: LineStyle
    var id: String { title }
}

// MARK: - Utilities

private func strideValues(upTo count: Int) -> [Int] {
    let safeCount = max(count, 1)
    let step = max(1, safeCount / 4)
    var values = Array(stride(from: 1, through: safeCount, by: step))
    if values.last != safeCount { values.append(safeCount) }
    return values
}

private extension Array where Element == ReportLinePoint {
    subscript(valueAt day: Int) -> Double? {
        guard !isEmpty else { return nil }
        let safeIndex = Swift.max(0, Swift.min(day - 1, count - 1))
        return self[safeIndex].value
    }
}

private extension Double {
    func axisCurrency(code: String) -> String {
        guard self > 0 else { return "0" }
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
