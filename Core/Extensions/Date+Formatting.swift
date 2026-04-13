import Foundation

extension Date {
    func notyfiDayTitle(calendar: Calendar = .autoupdatingCurrent) -> String {
        let appLocale = NotyfiLocale.current()

        if calendar.isDateInToday(self) {
            return "Today".notyfiLocalized
        }

        if calendar.isDateInYesterday(self) {
            return "Yesterday".notyfiLocalized
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = appLocale
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: self).uppercased(with: appLocale)
    }

    func notyfiSectionTitle(calendar: Calendar = .autoupdatingCurrent) -> String {
        if calendar.isDateInToday(self) {
            return "Today".notyfiLocalized
        }

        return formatted(
            .dateTime
                .month(.wide)
                .day()
                .locale(NotyfiLocale.current())
        )
    }

    func notyfiTimeLabel() -> String {
        formatted(.dateTime.hour().minute().locale(NotyfiLocale.current()))
    }

    func notyfiDetailLabel() -> String {
        formatted(
            .dateTime
                .weekday(.wide)
                .month(.wide)
                .day()
                .hour()
                .minute()
                .locale(NotyfiLocale.current())
        )
    }
}
