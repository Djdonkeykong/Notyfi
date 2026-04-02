import SwiftUI

struct DatePickerSheetView: View {
    @Binding var selection: Date
    @Environment(\.dismiss) private var dismiss

    private let selectedRingColor = Color(red: 0.58, green: 0.43, blue: 0.96)
    private let dayCellSize: CGFloat = 42
    private let actionButtonWidth: CGFloat = 94
    private let actionButtonHeight: CGFloat = 38

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        return calendar
    }

    private var monthTitle: String {
        selection.formatted(.dateTime.month(.abbreviated).year())
    }

    private var weekdaySymbols: [String] {
        ["M", "T", "W", "T", "F", "S", "S"]
    }

    private var days: [CalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selection) else {
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
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                }
                .overlay {
                    Rectangle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                }
                .ignoresSafeArea()

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
                                .foregroundStyle(Color.black.opacity(0.58))
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
        }
    }

    private func dayColor(for date: Date) -> Color {
        if calendar.isDate(date, inSameDayAs: selection) {
            return .primary
        }

        if calendar.compare(date, to: selection, toGranularity: .day) == .orderedAscending {
            return .black.opacity(0.9)
        }

        return .black.opacity(0.26)
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
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(foregroundStyle)
                .frame(width: width, height: height)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.72))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.52), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DatePickerSheetView(selection: .constant(Date(timeIntervalSince1970: 1775080800)))
}
