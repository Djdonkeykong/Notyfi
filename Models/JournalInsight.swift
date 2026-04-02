import Foundation

struct JournalInsight {
    var dayTotal: Double
    var monthTotal: Double
    var topCategory: ExpenseCategory?
    var reviewCount: Int

    static let empty = JournalInsight(
        dayTotal: 0,
        monthTotal: 0,
        topCategory: nil,
        reviewCount: 0
    )
}

