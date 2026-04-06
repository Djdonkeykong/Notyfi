import Foundation

extension Date {
    func notyfiDayTitle(calendar: Calendar = .autoupdatingCurrent) -> String {
        if calendar.isDateInToday(self) {
            return "Today".notyfiLocalized
        }

        if calendar.isDateInYesterday(self) {
            return "Yesterday".notyfiLocalized
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: self).uppercased(with: .autoupdatingCurrent)
    }

    func notyfiSectionTitle(calendar: Calendar = .autoupdatingCurrent) -> String {
        if calendar.isDateInToday(self) {
            return "Today".notyfiLocalized
        }

        return formatted(.dateTime.month(.wide).day())
    }

    func notyfiTimeLabel() -> String {
        formatted(date: .omitted, time: .shortened)
    }

    func notyfiDetailLabel() -> String {
        formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute())
    }
}
