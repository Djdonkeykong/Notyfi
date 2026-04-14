import SwiftUI

struct DatePickerSheetView: View {
    @Binding var selection: Date
    @Binding var visibleMonth: Date
    let entryDates: [Date]
    @Environment(\.dismiss) private var dismiss
    @State private var isMonthChooserPresented = false
    @State private var chooserYear = Calendar.autoupdatingCurrent.component(.year, from: Date())

    private let selectedRingColor = Color(red: 0.0, green: 0.0, blue: 0.996)
    private let entryFillColor = Color(red: 0.58, green: 0.88, blue: 0.62)
    private let dayCellSize: CGFloat = 46
    private let actionButtonWidth: CGFloat = 94
    private let actionButtonHeight: CGFloat = 44

    private var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = NotyfiLocale.current()
        return calendar
    }

    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: visibleMonth)?.start ?? visibleMonth
    }

    private var monthTitle: String {
        monthStart.formatted(
            .dateTime
                .month(.abbreviated)
                .year()
                .locale(NotyfiLocale.current())
        )
    }

    private var monthSymbols: [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = NotyfiLocale.current()
        return formatter.shortStandaloneMonthSymbols ?? formatter.shortMonthSymbols ?? []
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = NotyfiLocale.current()
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? []

        guard symbols.count == 7 else {
            return ["M", "T", "W", "T", "F", "S", "S"]
        }

        let leadingIndex = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[leadingIndex...]) + Array(symbols[..<leadingIndex])
    }

    private var days: [CalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else {
            return []
        }

        let monthStart = monthInterval.start
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 0
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingEmptyDays = (weekday - calendar.firstWeekday + 7) % 7

        var items: [CalendarDay] = Array(repeating: .empty, count: leadingEmptyDays)

        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                items.append(.date(day: day, date: date))
            }
        }

        while items.count % 7 != 0 {
            items.append(.empty)
        }

        return items
    }

    var body: some View {
        ZStack {
            backgroundSurface

            VStack(spacing: 20) {
                HStack {
                    CalendarPillButton(
                        title: "Today",
                        foregroundStyle: AnyShapeStyle(Color(red: 0.12, green: 0.46, blue: 0.98)),
                        width: actionButtonWidth,
                        height: actionButtonHeight,
                        action: {
                            Haptics.mediumImpact()
                            selection = Date()
                            visibleMonth = Date()
                            chooserYear = calendar.component(.year, from: Date())
                            isMonthChooserPresented = false
                        }
                    )

                    Spacer()

                    Button(action: toggleMonthChooser) {
                        HStack(spacing: 6) {
                            Text(monthTitle)
                                .font(.system(size: 17, weight: .semibold, design: .default))
                            Image(systemName: isMonthChooserPresented ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.primary.opacity(0.96))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    CalendarPillButton(
                        title: "Done",
                        foregroundStyle: AnyShapeStyle(.primary.opacity(0.9)),
                        width: actionButtonWidth,
                        height: actionButtonHeight,
                        action: {
                            Haptics.mediumImpact()
                            dismiss()
                        }
                    )
                }

                ZStack(alignment: .top) {
                    VStack(spacing: 16) {
                        HStack {
                            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                                Text(symbol)
                                    .font(.system(size: 15, weight: .medium, design: .default))
                                    .foregroundStyle(NotyfiTheme.secondaryText)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 14) {
                            ForEach(Array(days.enumerated()), id: \.offset) { _, item in
                                switch item {
                                case .empty:
                                    Color.clear
                                        .frame(height: dayCellSize)
                                case let .date(day, date):
                                    Button(action: {
                                        Haptics.mediumImpact()
                                        selection = date
                                    }) {
                                        Text("\(day)")
                                            .font(.system(size: 18, weight: calendar.isDate(date, inSameDayAs: selection) ? .semibold : .regular, design: .default))
                                            .foregroundStyle(dayColor(for: date))
                                            .frame(width: dayCellSize, height: dayCellSize)
                                            .background {
                                                if hasEntry(on: date) {
                                                    Circle()
                                                        .fill(entryFillColor.opacity(calendar.compare(date, to: Date(), toGranularity: .day) == .orderedDescending ? 0.48 : 1))
                                                }

                                                if calendar.isDate(date, inSameDayAs: selection) {
                                                    Circle()
                                                        .stroke(selectedRingColor, lineWidth: 3)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                    .allowsHitTesting(!isMonthChooserPresented)

                    if isMonthChooserPresented {
                        Rectangle()
                            .fill(Color.black.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .transition(.opacity)

                        monthChooserCard
                            .padding(.top, 2)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaPadding(.top, 6)
            .onChange(of: selection) { _, newValue in
                visibleMonth = newValue
                chooserYear = calendar.component(.year, from: newValue)
            }
            .onChange(of: visibleMonth) { _, newValue in
                chooserYear = calendar.component(.year, from: newValue)
            }
        }
    }

    @ViewBuilder
    private var backgroundSurface: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(in: .rect(cornerRadius: 0))
                .ignoresSafeArea()
        } else {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Rectangle()
                        .fill(Color.black.opacity(0.04))
                }
                .overlay {
                    Rectangle()
                        .fill(NotyfiTheme.glassOverlay)
                }
                .overlay {
                    Rectangle()
                        .stroke(NotyfiTheme.glassStroke, lineWidth: 1)
                }
                .ignoresSafeArea()
        }
    }

    private func dayColor(for date: Date) -> Color {
        if calendar.compare(date, to: Date(), toGranularity: .day) == .orderedDescending {
            return NotyfiTheme.tertiaryText
        }

        if calendar.isDate(date, inSameDayAs: selection) {
            return .primary
        }

        return .primary.opacity(0.9)
    }

    private func hasEntry(on date: Date) -> Bool {
        entryDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    private func toggleMonthChooser() {
        chooserYear = calendar.component(.year, from: visibleMonth)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            isMonthChooserPresented.toggle()
        }
    }

    private func jumpToMonth(monthIndex: Int) {
        guard let january = calendar.date(from: DateComponents(year: chooserYear, month: 1, day: 1)),
              let targetMonth = calendar.date(byAdding: .month, value: monthIndex, to: january) else {
            return
        }

        let targetMonthStart = calendar.dateInterval(of: .month, for: targetMonth)?.start ?? targetMonth
        let preferredDay = calendar.component(.day, from: selection)
        let daysInTargetMonth = calendar.range(of: .day, in: .month, for: targetMonthStart)?.count ?? preferredDay
        let targetDay = max(1, min(preferredDay, daysInTargetMonth))

        visibleMonth = targetMonthStart

        if let resolvedDate = calendar.date(byAdding: .day, value: targetDay - 1, to: targetMonthStart) {
            Haptics.mediumImpact()
            selection = resolvedDate
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            isMonthChooserPresented = false
        }
    }

    @ViewBuilder
    private var monthChooserCard: some View {
        VStack(spacing: 18) {
            HStack {
                CircleChevronButton(direction: .left) {
                    Haptics.mediumImpact()
                    chooserYear -= 1
                }

                Spacer()

                Text("\(chooserYear)")
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundStyle(.primary.opacity(0.96))

                Spacer()

                CircleChevronButton(direction: .right) {
                    Haptics.mediumImpact()
                    chooserYear += 1
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(Array(monthSymbols.enumerated()), id: \.offset) { index, symbol in
                    Button(action: {
                        jumpToMonth(monthIndex: index)
                    }) {
                        Text(symbol)
                            .font(.system(size: 15, weight: .semibold, design: .default))
                            .foregroundStyle(monthButtonTextColor(for: index))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(monthButtonBackground(for: index))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                                            .stroke(monthButtonBorder(for: index), lineWidth: currentMonthIndex == index && chooserYear == currentVisibleYear ? 2 : 1)
                                    }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(NotyfiTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(NotyfiTheme.surfaceBorder, lineWidth: 1)
                }
        }
        .shadow(color: Color.black.opacity(0.08), radius: 18, y: 8)
    }

    private var currentMonthIndex: Int {
        calendar.component(.month, from: visibleMonth) - 1
    }

    private var currentVisibleYear: Int {
        calendar.component(.year, from: visibleMonth)
    }

    private func monthButtonBackground(for index: Int) -> Color {
        currentMonthIndex == index && chooserYear == currentVisibleYear
            ? selectedRingColor.opacity(0.18)
            : NotyfiTheme.surface
    }

    private func monthButtonBorder(for index: Int) -> Color {
        currentMonthIndex == index && chooserYear == currentVisibleYear
            ? selectedRingColor
            : NotyfiTheme.surfaceBorder
    }

    private func monthButtonTextColor(for index: Int) -> Color {
        currentMonthIndex == index && chooserYear == currentVisibleYear
            ? selectedRingColor
            : .primary.opacity(0.88)
    }
}

private enum CalendarDay {
    case empty
    case date(day: Int, date: Date)
}

private struct CalendarPillButton: View {
    let title: String
    let foregroundStyle: AnyShapeStyle
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.notyfiLocalized)
                .font(.system(size: 15, weight: .semibold, design: .default))
                .foregroundStyle(foregroundStyle)
                .frame(width: width, height: height)
                .background {
                    Capsule(style: .continuous)
                        .fill(NotyfiTheme.surface)
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(NotyfiTheme.surfaceBorder, lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DatePickerSheetView(
        selection: .constant(Date(timeIntervalSince1970: 1775080800)),
        visibleMonth: .constant(Date(timeIntervalSince1970: 1775080800)),
        entryDates: [
            Date(timeIntervalSince1970: 1775080800),
            Date(timeIntervalSince1970: 1774994400)
        ]
    )
}
