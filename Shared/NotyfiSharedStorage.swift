import Foundation

enum NotyfiSharedStorage {
    static let appGroupID = "group.com.djdonkeykong.notely"
    static let financeSnapshotKey = "notyfi.shared.finance-snapshot"
    static let reminderEnabledKey = "notyfi.reminder.enabled"
    static let reminderHourKey = "notyfi.reminder.hour"
    static let reminderMinuteKey = "notyfi.reminder.minute"

    static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}

struct NotyfiFinanceSnapshot: Codable, Equatable {
    var generatedAt: Date
    var currencyCode: String
    var todaySpent: Double
    var monthSpent: Double
    var monthIncome: Double
    var monthNet: Double
    var monthlyBudgetLimit: Double
    var budgetLeft: Double
    var hasBudget: Bool
    var hasEntries: Bool

    static let empty = NotyfiFinanceSnapshot(
        generatedAt: .distantPast,
        currencyCode: NotyfiCurrency.currentCode(),
        todaySpent: 0,
        monthSpent: 0,
        monthIncome: 0,
        monthNet: 0,
        monthlyBudgetLimit: 0,
        budgetLeft: 0,
        hasBudget: false,
        hasEntries: false
    )
}

struct NotyfiReminderSettings: Equatable {
    var isEnabled: Bool
    var hour: Int
    var minute: Int

    static let `default` = NotyfiReminderSettings(
        isEnabled: false,
        hour: 20,
        minute: 0
    )

    var dateComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }
}
