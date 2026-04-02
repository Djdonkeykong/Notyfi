import Foundation

extension Date {
    func notelyDayTitle(calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(self) {
            return "Today"
        }

        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self).uppercased()
    }

    func notelySectionTitle(calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(self) {
            return "Today"
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
