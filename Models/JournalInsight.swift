import Foundation

struct JournalInsight {
    var dayExpenseTotal: Double
    var dayIncomeTotal: Double
    var dayNetTotal: Double
    var monthExpenseTotal: Double
    var monthIncomeTotal: Double
    var monthNetTotal: Double
    var topCategory: ExpenseCategory?
    var reviewCount: Int
    var monthEntryCount: Int = 0
    var monthAveragePerEntry: Double = 0
    var topCategoryShare: Double = 0
    var categoryBreakdown: [JournalCategoryBreakdown] = []

    static let empty = JournalInsight(
        dayExpenseTotal: 0,
        dayIncomeTotal: 0,
        dayNetTotal: 0,
        monthExpenseTotal: 0,
        monthIncomeTotal: 0,
        monthNetTotal: 0,
        topCategory: nil,
        reviewCount: 0,
        monthEntryCount: 0,
        monthAveragePerEntry: 0,
        topCategoryShare: 0,
        categoryBreakdown: []
    )
}

struct JournalCategoryBreakdown: Identifiable, Hashable {
    var category: ExpenseCategory
    var total: Double
    var share: Double
    var entryCount: Int

    var id: String {
        category.rawValue
    }
}
