import Foundation

extension Date {
    func notelyDayTitle(calendar: Calendar = .autoupdatingCurrent) -> String {
        if calendar.isDateInToday(self) {
            return "Today".notelyLocalized
        }

        if calendar.isDateInYesterday(self) {
            return "Yesterday".notelyLocalized
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: self).uppercased(with: .autoupdatingCurrent)
    }

    func notelySectionTitle(calendar: Calendar = .autoupdatingCurrent) -> String {
        if calendar.isDateInToday(self) {
            return "Today".notelyLocalized
        }

        return formatted(.dateTime.month(.wide).day())
    }

    func notelyTimeLabel() -> String {
        formatted(date: .omitted, time: .shortened)
    }

    func notelyDetailLabel() -> String {
        formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute())
    }
}
