import Foundation

struct JournalInsight {
    var dayTotal: Double
    var monthTotal: Double
    var topCategory: ExpenseCategory?
    var reviewCount: Int
    var monthEntryCount: Int = 0
    var monthAveragePerEntry: Double = 0
    var topCategoryShare: Double = 0
    var categoryBreakdown: [JournalCategoryBreakdown] = []

    static let empty = JournalInsight(
        dayTotal: 0,
        monthTotal: 0,
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
