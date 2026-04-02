import SwiftUI

struct DatePickerSheetView: View {
    @Binding var selection: Date
    @Environment(\.dismiss) private var dismiss

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
            NotelyTheme.background
                .opacity(0.9)
                .ignoresSafeArea()

            VStack {
                VStack(spacing: 18) {
                    HStack {
                        CalendarPillButton(
                            title: "Today",
                            foregroundStyle: AnyShapeStyle(.blue),
                            action: {
                                Haptics.mediumImpact()
                                selection = Date()
                            }
                        )

                        Spacer()

                        Text(monthTitle)
                            .font(.notely(.title3, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.92))

                        Spacer()

                        CalendarPillButton(
                            title: "Done",
                            foregroundStyle: AnyShapeStyle(.primary.opacity(0.9)),
                            action: {
                                Haptics.mediumImpact()
                                dismiss()
                            }
                        )
                    }

                    VStack(spacing: 18) {
                        HStack {
                            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                                Text(symbol)
                                    .font(.notely(.footnote, weight: .medium))
                                    .foregroundStyle(NotelyTheme.secondaryText)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 20) {
                            ForEach(Array(days.enumerated()), id: \.offset) { _, item in
                                switch item {
                                case .empty:
                                    Color.clear
                                        .frame(height: 34)
                                case let .date(day, date):
                                    Button(action: {
                                        Haptics.mediumImpact()
                                        selection = date
                                    }) {
                                        Text("\(day)")
                                            .font(.notely(.title3, weight: calendar.isDate(date, inSameDayAs: selection) ? .semibold : .regular))
                                            .foregroundStyle(dayColor(for: date))
                                            .frame(width: 34, height: 34)
                                            .background {
                                                if calendar.isDate(date, inSameDayAs: selection) {
                                                    Circle()
                                                        .stroke(Color(red: 0.58, green: 0.43, blue: 0.96), lineWidth: 3)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 30)
                .background {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                        .overlay {
                            RoundedRectangle(cornerRadius: 36, style: .continuous)
                                .stroke(Color.white.opacity(0.72), lineWidth: 1)
                        }
                        .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 10)
                }
                .padding(.horizontal, 4)
                .padding(.top, 10)

                Spacer(minLength: 0)
            }
            .safeAreaPadding(.top, 6)
        }
    }

    private func dayColor(for date: Date) -> Color {
        if calendar.isDate(date, inSameDayAs: selection) {
            return .primary
        }

        if calendar.compare(date, to: selection, toGranularity: .day) == .orderedAscending {
            return .black.opacity(0.85)
        }

        return .black.opacity(0.25)
    }
}

private enum CalendarDay {
    case empty
    case date(day: Int, date: Date)
}

private struct CalendarPillButton: View {
    let title: String
    let foregroundStyle: AnyShapeStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.notely(.body, weight: .semibold))
                .foregroundStyle(foregroundStyle)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background {
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DatePickerSheetView(selection: .constant(Date(timeIntervalSince1970: 1775080800)))
}
