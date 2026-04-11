import Foundation

enum NotyfiSharedStorage {
    static let appGroupID = "group.com.djdonkeykong.notely"
    static let financeSnapshotKey = "notyfi.shared.finance-snapshot"
    static let reminderEnabledKey = "notyfi.reminder.enabled"
    static let reminderHourKey = "notyfi.reminder.hour"
    static let reminderMinuteKey = "notyfi.reminder.minute"
    static let reminderFrequencyKey = "notyfi.reminder.frequency"

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

enum ReminderFrequency: Int, CaseIterable {
    case subtle  = 0
    case light   = 1
    case regular = 2
    case often   = 3
    case max     = 4

    var label: String {
        switch self {
        case .subtle:  return "Freq Subtle".notyfiLocalized
        case .light:   return "Freq Light".notyfiLocalized
        case .regular: return "Freq Regular".notyfiLocalized
        case .often:   return "Freq Often".notyfiLocalized
        case .max:     return "Freq Max".notyfiLocalized
        }
    }

    // Hours of the day at which notifications fire
    var notificationHours: [Int] {
        switch self {
        case .subtle:  return [20]
        case .light:   return [9, 20]
        case .regular: return [9, 14, 20]
        case .often:   return [8, 11, 14, 17, 20]
        case .max:     return [8, 10, 12, 14, 16, 18, 20, 22]
        }
    }
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
