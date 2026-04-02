import Foundation

extension Date {
    func notelyDayTitle(calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(self) {
            return "Today"
        }

        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }

        if calendar.isDateInTomorrow(self) {
            return "Tomorrow"
        }

        return formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
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

