import Foundation

struct BudgetPlan: Codable, Equatable {
    var monthlySpendingLimit: Double
    var monthlySavingsTarget: Double
    var categoryTargets: [BudgetCategoryTarget]

    static let empty = BudgetPlan(
        monthlySpendingLimit: 0,
        monthlySavingsTarget: 0,
        categoryTargets: []
    )

    var hasSpendingLimit: Bool {
        monthlySpendingLimit > 0
    }

    var hasSavingsTarget: Bool {
        monthlySavingsTarget > 0
    }

    func target(for category: ExpenseCategory) -> Double {
        categoryTargets.first(where: { $0.category == category })?.amount ?? 0
    }

    mutating func setMonthlySpendingLimit(_ amount: Double) {
        monthlySpendingLimit = max(0, amount)
    }

    mutating func setMonthlySavingsTarget(_ amount: Double) {
        monthlySavingsTarget = max(0, amount)
    }

    mutating func setCategoryTarget(_ amount: Double, for category: ExpenseCategory) {
        let normalizedAmount = max(0, amount)

        if let index = categoryTargets.firstIndex(where: { $0.category == category }) {
            if normalizedAmount == 0 {
                categoryTargets.remove(at: index)
            } else {
                categoryTargets[index].amount = normalizedAmount
            }
        } else if normalizedAmount > 0 {
            categoryTargets.append(
                BudgetCategoryTarget(category: category, amount: normalizedAmount)
            )
        }

        categoryTargets.sort { lhs, rhs in
            lhs.category.title < rhs.category.title
        }
    }
}

struct BudgetCategoryTarget: Codable, Identifiable, Hashable {
    var category: ExpenseCategory
    var amount: Double

    var id: String {
        category.id
    }
}

struct BudgetInsight {
    enum Status: Equatable {
        case needsBudget
        case balanced
        case caution
        case overBudget

        var title: String {
            switch self {
            case .needsBudget:
                return "Set a monthly budget".notyfiLocalized
            case .balanced:
                return "On pace this month".notyfiLocalized
            case .caution:
                return "Running a little hot".notyfiLocalized
            case .overBudget:
                return "Over budget".notyfiLocalized
            }
        }
    }

    var plan: BudgetPlan
    var status: Status
    var spentThisMonth: Double
    var incomeThisMonth: Double
    var netThisMonth: Double
    var averageDailySpend: Double
    var projectedExpenseTotal: Double
    var remainingBudget: Double
    var spendingProgress: Double
    var remainingSavingsTarget: Double
    var savingsProgress: Double
    var daysElapsed: Int
    var daysInMonth: Int
    var suggestedMonthlyBudget: Double?
    var categoryStatuses: [BudgetCategoryStatus]

    static let empty = BudgetInsight(
        plan: .empty,
        status: .needsBudget,
        spentThisMonth: 0,
        incomeThisMonth: 0,
        netThisMonth: 0,
        averageDailySpend: 0,
        projectedExpenseTotal: 0,
        remainingBudget: 0,
        spendingProgress: 0,
        remainingSavingsTarget: 0,
        savingsProgress: 0,
        daysElapsed: 1,
        daysInMonth: 30,
        suggestedMonthlyBudget: nil,
        categoryStatuses: []
    )
}

struct BudgetCategoryStatus: Identifiable, Hashable {
    var category: ExpenseCategory
    var spent: Double
    var target: Double
    var share: Double
    var entryCount: Int

    var id: String {
        category.id
    }

    var remaining: Double {
        target - spent
    }

    var hasTarget: Bool {
        target > 0
    }

    var progress: Double {
        guard target > 0 else {
            return 0
        }

        return min(max(spent / target, 0), 1)
    }

    var isActive: Bool {
        spent > 0 || target > 0
    }
}
