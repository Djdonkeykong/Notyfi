import Foundation
import UIKit
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
        // FCM covers the 20:00 slot for users with push registered — skip it locally
        // to avoid duplicate notifications from both channels at the same time.
        let pushActive = UIApplication.shared.isRegisteredForRemoteNotifications
        let hours = pushActive
            ? frequency.notificationHours.filter { $0 != 20 }
            : frequency.notificationHours

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

        return pool.shuffled()
    }
}

// MARK: - Message model

struct NotificationMessage {
    let title: String
    let body: String

    // Computed each call so language changes are picked up immediately
    static var genericReminders: [NotificationMessage] {
        [
            .init(
                title: "notif.generic.checkin.title".notyfiLocalized,
                body: "notif.generic.checkin.body".notyfiLocalized
            ),
            .init(
                title: "notif.generic.moneynotes.title".notyfiLocalized,
                body: "notif.generic.moneynotes.body".notyfiLocalized
            ),
            .init(
                title: "notif.generic.dontforget.title".notyfiLocalized,
                body: "notif.generic.dontforget.body".notyfiLocalized
            ),
            .init(
                title: "notif.generic.logday.title".notyfiLocalized,
                body: "notif.generic.logday.body".notyfiLocalized
            ),
            .init(
                title: "notif.generic.stayontrack.title".notyfiLocalized,
                body: "notif.generic.stayontrack.body".notyfiLocalized
            ),
            .init(
                title: "notif.generic.open.title".notyfiLocalized,
                body: "notif.generic.open.body".notyfiLocalized
            ),
            .init(
                title: "notif.generic.journaltime.title".notyfiLocalized,
                body: "notif.generic.journaltime.body".notyfiLocalized
            ),
            .init(
                title: "notif.generic.whatdidyouspend.title".notyfiLocalized,
                body: "notif.generic.whatdidyouspend.body".notyfiLocalized
            ),
        ]
    }
}

// MARK: - Behavior analysis

@MainActor
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
            .init(
                title: String(format: "notif.streak.days.title".notyfiLocalized, streak),
                body: "notif.streak.consistent.body".notyfiLocalized
            ),
            .init(
                title: "notif.streak.roll.title".notyfiLocalized,
                body: String(format: "notif.streak.roll.body".notyfiLocalized, streak, streak + 1)
            ),
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
        let remainingStr = remaining.formattedCurrency(code: currencyCode)

        if percent >= 0.9 {
            return [
                .init(
                    title: "notif.budget.nearlygone.title".notyfiLocalized,
                    body: String(format: "notif.budget.nearlygone.body".notyfiLocalized, Int(percent * 100), remainingStr)
                ),
                .init(
                    title: "notif.budget.almostover.title".notyfiLocalized,
                    body: String(format: "notif.budget.almostover.body".notyfiLocalized, remainingStr, daysLeft)
                ),
            ]
        } else if percent >= 0.7 {
            return [
                .init(
                    title: "notif.budget.check.title".notyfiLocalized,
                    body: String(format: "notif.budget.check.body".notyfiLocalized, Int(percent * 100), remainingStr, daysLeft)
                ),
            ]
        } else if percent < 0.5 && daysLeft <= 7 {
            return [
                .init(
                    title: "notif.budget.lookinggood.title".notyfiLocalized,
                    body: String(format: "notif.budget.lookinggood.body".notyfiLocalized, remainingStr, daysLeft)
                ),
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
            let categoryTitle = category.title
            if ratio >= 1.1 {
                messages.append(.init(
                    title: String(format: "notif.category.overtarget.title".notyfiLocalized, categoryTitle),
                    body: String(format: "notif.category.overtarget.body".notyfiLocalized, Int(ratio * 100), categoryTitle)
                ))
            } else if ratio >= 0.85 {
                messages.append(.init(
                    title: String(format: "notif.category.almostcap.title".notyfiLocalized, categoryTitle),
                    body: String(format: "notif.category.almostcap.body".notyfiLocalized, Int(ratio * 100), categoryTitle, (target - spent).formattedCurrency(code: currencyCode))
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
                .init(
                    title: "notif.savings.hit.title".notyfiLocalized,
                    body: "notif.savings.hit.body".notyfiLocalized
                ),
            ]
        } else if remaining < target * 0.2 {
            return [
                .init(
                    title: "notif.savings.almost.title".notyfiLocalized,
                    body: String(format: "notif.savings.almost.body".notyfiLocalized, remaining.formattedCurrency(code: currencyCode))
                ),
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
                let when: String
                if days == 0 {
                    when = "notif.recurring.today".notyfiLocalized
                } else if days == 1 {
                    when = "notif.recurring.tomorrow".notyfiLocalized
                } else {
                    when = String(format: "notif.recurring.indays".notyfiLocalized, days)
                }
                return NotificationMessage(
                    title: String(format: "notif.recurring.title".notyfiLocalized, when),
                    body: String(format: "notif.recurring.body".notyfiLocalized, transaction.title, transaction.amount.formattedCurrency(code: transaction.currencyCode), when)
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
            .init(
                title: "notif.weekly.title".notyfiLocalized,
                body: String(format: "notif.weekly.body".notyfiLocalized, weekSpend.formattedCurrency(code: currencyCode))
            ),
        ]
    }

    // MARK: Missed yesterday

    func missedYesterdayMessages() -> [NotificationMessage] {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return [] }
        let loggedYesterday = store.entries.contains { calendar.isDate($0.date, inSameDayAs: yesterday) }
        guard !loggedYesterday else { return [] }

        return [
            .init(
                title: "notif.missed.title".notyfiLocalized,
                body: "notif.missed.body".notyfiLocalized
            ),
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
