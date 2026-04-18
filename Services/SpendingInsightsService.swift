import Foundation
import Supabase

struct SpendingInsight: Codable, Identifiable {
    let id: String
    let headline: String
    let body: String
    let tag: Tag

    enum Tag: String, Codable {
        case overspending
        case savingOpportunity = "saving_opportunity"
        case pattern
        case positive
    }
}

struct InsightsResult: Codable {
    let narrative: String
    let insights: [SpendingInsight]
}

struct SpendingInsightsService {
    func generate(
        monthLabel: String,
        currencyCode: String,
        expenseTotal: Double,
        incomeTotal: Double,
        budgetLimit: Double,
        categoryTotals: [CategoryTotal],
        previousMonthExpenseTotal: Double,
        topMerchants: [String]
    ) async throws -> InsightsResult {
        let request = Request(
            monthLabel: monthLabel,
            currencyCode: currencyCode,
            languageCode: NotyfiLocale.storedLanguageCode(defaults: .standard),
            expenseTotal: expenseTotal,
            incomeTotal: incomeTotal,
            budgetLimit: budgetLimit,
            categoryTotals: categoryTotals,
            previousMonthExpenseTotal: previousMonthExpenseTotal,
            topMerchants: topMerchants
        )

        return try await SupabaseService.client.functions.invoke(
            "spending-insights",
            options: FunctionInvokeOptions(body: request)
        )
    }

    struct CategoryTotal: Encodable {
        let category: String
        let total: Double
        let entryCount: Int
    }

    private struct Request: Encodable {
        let monthLabel: String
        let currencyCode: String
        let languageCode: String
        let expenseTotal: Double
        let incomeTotal: Double
        let budgetLimit: Double
        let categoryTotals: [CategoryTotal]
        let previousMonthExpenseTotal: Double
        let topMerchants: [String]
    }
}
