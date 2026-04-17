import Foundation
import UserNotifications

// Schedules smart, behavior-aware local notifications for the next 7 days.
// Called on every app foreground so messages stay fresh and contextual.
@MainActor
final class NotificationContentEngine {
    static let shared = NotificationContentEngine()

    private let center = UNUserNotificationCenter.current()
    private let idPrefix = "notyfi.smart"
    private let daysAhead = 7

    func reschedule(store: ExpenseJournalStore) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        guard NotyfiReminderManager.shared.loadSettings().isEnabled else { return }

        let frequency = NotyfiReminderManager.shared.loadFrequency()
        let hours = frequency.notificationHours

        // Clear previous smart and legacy frequency notifications
        let oldIDs = (0..<64).map { "\(idPrefix).\($0)" }
            + (0..<8).map { "notyfi.reminder.freq.\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: oldIDs)

        let messages = buildMessagePool(store: store)
        guard !messages.isEmpty else { return }

        let calendar = Calendar.current
        var index = 0

        for dayOffset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: .now) else { continue }
            let dayBase = calendar.dateComponents([.year, .month, .day], from: day)

            for hour in hours {
                var components = dayBase
                components.hour = hour
                components.minute = 0
                components.second = 0

                guard let fireDate = calendar.date(from: components), fireDate > .now else { continue }

                let msg = messages[index % messages.count]
                let content = UNMutableNotificationContent()
                content.title = msg.title
                content.body = msg.body
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: "\(idPrefix).\(index)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                )
                try? await center.add(request)
                index += 1
            }
        }
    }

    // MARK: - Message pool

    private func buildMessagePool(store: ExpenseJournalStore) -> [NotificationMessage] {
        let analysis = BehaviorAnalysis(store: store)
        var pool: [NotificationMessage] = []

        pool += NotificationMessage.genericReminders

        pool += analysis.streakMessages()
        pool += analysis.budgetMessages()
        pool += analysis.categoryMessages()
        pool += analysis.savingsMessages()
        pool += analysis.recurringMessages()
        pool += analysis.weeklyInsightMessages()
        pool += analysis.missedYesterdayMessages()

        // Shuffle for variety; iOS delivers them in scheduled order
        return pool.shuffled()
    }
}

// MARK: - Message model

struct NotificationMessage {
    let title: String
    let body: String

    static let genericReminders: [NotificationMessage] = [
        .init(title: "Quick check-in",
              body: "Any spending today? Tap to log it while it's fresh."),
        .init(title: "Money notes",
              body: "The best time to log is right after spending. Second best? Now."),
        .init(title: "Don't forget",
              body: "Small habits, big clarity. Take 30 seconds to log today."),
        .init(title: "Log your day",
              body: "Your future self will thank you. Anything to add?"),
        .init(title: "Stay on track",
              body: "Keeping track takes seconds. Your budget will thank you."),
        .init(title: "Open Notyfi",
              body: "Capture today's spending while it's still fresh in your mind."),
        .init(title: "Journal time",
              body: "A quick log now saves a lot of guessing later."),
        .init(title: "What did you spend?",
              body: "Your wallet remembers everything. Your brain doesn't. Log now."),
    ]
}

// MARK: - Behavior analysis

private struct BehaviorAnalysis {
    let store: ExpenseJournalStore
    let calendar = Calendar.current
    let now = Date()
    let currencyCode = NotyfiCurrency.currentCode()

    // MARK: Streak

    func streakMessages() -> [NotificationMessage] {
        let streak = currentStreak()
        guard streak >= 3 else { return [] }
        return [
            .init(title: "\(streak) days in a row",
                  body: "You've been consistent. Keep the streak alive today."),
            .init(title: "On a roll",
                  body: "\(streak) days of logging. Today makes \(streak + 1)."),
        ]
    }

    private func currentStreak() -> Int {
        var streak = 0
        var checkDate = calendar.startOfDay(for: now)
        while true {
            let hasEntry = store.entries.contains { calendar.isDate($0.date, inSameDayAs: checkDate) }
            guard hasEntry else { break }
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    // MARK: Budget

    func budgetMessages() -> [NotificationMessage] {
        let plan = store.budgetPlan
        guard plan.hasSpendingLimit else { return [] }

        let spent = monthExpenses()
        let limit = plan.monthlySpendingLimit
        let percent = spent / limit
        let remaining = limit - spent
        let daysLeft = daysRemainingInMonth()

        if percent >= 0.9 {
            return [
                .init(title: "Budget nearly gone",
                      body: "\(Int(percent * 100))% used. Only \(remaining.formattedCurrency(code: currencyCode)) left this month."),
                .init(title: "Almost over budget",
                      body: "\(remaining.formattedCurrency(code: currencyCode)) left with \(daysLeft) days to go. Tread carefully."),
            ]
        } else if percent >= 0.7 {
            return [
                .init(title: "Budget check",
                      body: "You've used \(Int(percent * 100))% this month. \(remaining.formattedCurrency(code: currencyCode)) left over \(daysLeft) days."),
            ]
        } else if percent < 0.5 && daysLeft <= 7 {
            return [
                .init(title: "Looking good",
                      body: "\(remaining.formattedCurrency(code: currencyCode)) left with \(daysLeft) days remaining. You're on track."),
            ]
        }

        return []
    }

    // MARK: Categories

    func categoryMessages() -> [NotificationMessage] {
        var messages: [NotificationMessage] = []
        for category in store.trackedCategories {
            let target = store.budgetPlan.target(for: category)
            guard target > 0 else { continue }

            let spent = store.entries
                .filter {
                    calendar.isDate($0.date, equalTo: now, toGranularity: .month)
                    && $0.category == category
                    && $0.transactionKind == .expense
                }
                .reduce(0) { $0 + $1.amount }

            let ratio = spent / target
            if ratio >= 1.1 {
                messages.append(.init(
                    title: "\(category.title) over target",
                    body: "You're at \(Int(ratio * 100))% of your \(category.title) guide this month."
                ))
            } else if ratio >= 0.85 {
                messages.append(.init(
                    title: "\(category.title) almost at cap",
                    body: "\(Int(ratio * 100))% of your \(category.title) guide used. \((target - spent).formattedCurrency(code: currencyCode)) left."
                ))
            }
        }
        return messages
    }

    // MARK: Savings

    func savingsMessages() -> [NotificationMessage] {
        let plan = store.budgetPlan
        guard plan.hasSavingsTarget else { return [] }

        let target = plan.monthlySavingsTarget
        let saved = monthIncome() - monthExpenses()
        let remaining = target - saved

        if remaining <= 0 {
            return [
                .init(title: "Savings goal hit",
                      body: "You've hit your savings target this month. Nice work."),
            ]
        } else if remaining < target * 0.2 {
            return [
                .init(title: "Almost at your savings goal",
                      body: "Just \(remaining.formattedCurrency(code: currencyCode)) away from hitting your target."),
            ]
        }

        return []
    }

    // MARK: Recurring

    func recurringMessages() -> [NotificationMessage] {
        guard let threeDaysOut = calendar.date(byAdding: .day, value: 3, to: now) else { return [] }

        return store.recurringTransactions
            .filter { $0.isActive && $0.nextOccurrenceAt > now && $0.nextOccurrenceAt <= threeDaysOut }
            .map { transaction in
                let days = calendar.dateComponents([.day], from: now, to: transaction.nextOccurrenceAt).day ?? 0
                let when = days == 0 ? "today" : days == 1 ? "tomorrow" : "in \(days) days"
                return NotificationMessage(
                    title: "Upcoming charge \(when)",
                    body: "\(transaction.title) for \(transaction.amount.formattedCurrency(code: transaction.currencyCode)) is due \(when)."
                )
            }
    }

    // MARK: Weekly insight

    func weeklyInsightMessages() -> [NotificationMessage] {
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: now) else { return [] }

        let weekEntries = store.entries.filter { $0.date >= weekStart }
        let weekSpend = weekEntries
            .filter { $0.transactionKind == .expense }
            .reduce(0) { $0 + $1.amount }

        guard weekSpend > 0 else { return [] }

        return [
            .init(title: "Last 7 days",
                  body: "You've logged \(weekSpend.formattedCurrency(code: currencyCode)) in expenses over the past week."),
        ]
    }

    // MARK: Missed yesterday

    func missedYesterdayMessages() -> [NotificationMessage] {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return [] }
        let loggedYesterday = store.entries.contains { calendar.isDate($0.date, inSameDayAs: yesterday) }
        guard !loggedYesterday else { return [] }

        return [
            .init(title: "Yesterday unlogged",
                  body: "Nothing logged for yesterday — want to add anything from memory?"),
        ]
    }

    // MARK: Helpers

    private func monthExpenses() -> Double {
        store.entries
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) && $0.transactionKind == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    private func monthIncome() -> Double {
        store.entries
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) && $0.transactionKind == .income }
            .reduce(0) { $0 + $1.amount }
    }

    private func daysRemainingInMonth() -> Int {
        let range = calendar.range(of: .day, in: .month, for: now) ?? (1..<31)
        let day = calendar.component(.day, from: now)
        return range.count - day
    }
}
