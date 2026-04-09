import SwiftUI

struct DatePickerSheetView: View {
    @Binding var selection: Date
    @Binding var visibleMonth: Date
    let entryDates: [Date]
    @Environment(\.dismiss) private var dismiss
    @State private var horizontalDragOffset: CGFloat = 0
    @State private var isMonthTransitioning = false

    private let selectedRingColor = Color(red: 0.0, green: 0.0, blue: 0.996)
    private let entryFillColor = Color(red: 0.58, green: 0.88, blue: 0.62)
    private let dayCellSize: CGFloat = 46
    private let actionButtonWidth: CGFloat = 94
    private let actionButtonHeight: CGFloat = 44

    private var calendar: Calendar {
        Calendar.autoupdatingCurrent
    }

    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: visibleMonth)?.start ?? visibleMonth
    }

    private var monthTitle: String {
        monthStart.formatted(.dateTime.month(.abbreviated).year())
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .autoupdatingCurrent
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
        GeometryReader { geometry in
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
                            }
                        )

                        Spacer()

                        Text(monthTitle)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.96))

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

                    VStack(spacing: 16) {
                        HStack {
                            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                                Text(symbol)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
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
                                            .font(.system(size: 18, weight: calendar.isDate(date, inSameDayAs: selection) ? .semibold : .regular, design: .rounded))
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
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .safeAreaPadding(.top, 6)
                .offset(x: horizontalDragOffset)
                .gesture(monthSwipeGesture(containerWidth: geometry.size.width))
                .onChange(of: selection) { _, newValue in
                    visibleMonth = newValue
                }
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

    private func monthSwipeGesture(containerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard !isMonthTransitioning else {
                    return
                }

                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }

                let limit = min(containerWidth * 0.68, 220)
                horizontalDragOffset = min(max(value.translation.width * 0.72, -limit), limit)
            }
            .onEnded { value in
                guard !isMonthTransitioning else {
                    return
                }
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        horizontalDragOffset = 0
                    }
                    return
                }

                let threshold = min(containerWidth * 0.16, 72)
                if value.translation.width <= -threshold {
                    animateMonthTransition(by: 1, containerWidth: containerWidth)
                } else if value.translation.width >= threshold {
                    animateMonthTransition(by: -1, containerWidth: containerWidth)
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        horizontalDragOffset = 0
                    }
                }
            }
    }

    private func animateMonthTransition(by offset: Int, containerWidth: CGFloat) {
        isMonthTransitioning = true
        let travelDistance = min(containerWidth * 0.62, 260)
        let outgoingOffset = offset > 0 ? -travelDistance : travelDistance
        let incomingOffset = -outgoingOffset

        withAnimation(.easeOut(duration: 0.14)) {
            horizontalDragOffset = outgoingOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            moveMonth(by: offset)
            horizontalDragOffset = incomingOffset

            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                horizontalDragOffset = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                isMonthTransitioning = false
            }
        }
    }

    private func moveMonth(by offset: Int) {
        guard let targetMonth = calendar.date(byAdding: .month, value: offset, to: monthStart) else {
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
                .font(.system(size: 15, weight: .semibold, design: .rounded))
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
