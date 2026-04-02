import Foundation

struct ParsedExpenseDraft {
    var rawText: String
    var title: String
    var amount: Double
    var currencyCode: String
    var category: ExpenseCategory
    var merchant: String?
    var note: String
    var confidence: ParsingConfidence
}

protocol ExpenseParsingServicing {
    func parse(rawText: String, date: Date, currencyCode: String) -> ParsedExpenseDraft
}

struct PlaceholderExpenseParsingService: ExpenseParsingServicing {
    func parse(rawText: String, date: Date, currencyCode: String) -> ParsedExpenseDraft {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        let amountToken = extractAmountMatch(from: lowercased)
        let amount = amountToken
            .map { $0.replacingOccurrences(of: ",", with: ".") }
            .flatMap(Double.init) ?? 0
        let merchant = extractMerchant(from: trimmed)
        let category = categorize(text: lowercased)
        let title = cleanedTitle(from: trimmed, merchant: merchant, amountToken: amountToken)
        let confidence: ParsingConfidence

        if amount > 0, title.count > 1 {
            confidence = (merchant == nil && category != .uncategorized) ? .certain : .review
        } else {
            confidence = .uncertain
        }

        return ParsedExpenseDraft(
            rawText: trimmed,
            title: title.isEmpty ? "Untitled expense" : title,
            amount: amount > 0 ? amount : 0,
            currencyCode: currencyCode,
            category: category,
            merchant: merchant,
            note: "",
            confidence: confidence
        )
    }

    private func extractAmountMatch(from text: String) -> String? {
        let pattern = #"(\d+[.,]?\d{0,2})"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.matches(
                in: text,
                range: NSRange(text.startIndex..., in: text)
            ).last,
            let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        return String(text[range])
    }

    private func extractMerchant(from text: String) -> String? {
        let pattern = #"\bat\s+([A-Za-z0-9&'\-\s]+?)(?:\s+\d+[.,]?\d{0,2}\s*(?:kr|nok)?)?$"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        let merchant = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
        return merchant.isEmpty ? nil : merchant
    }

    private func cleanedTitle(from text: String, merchant: String?, amountToken: String?) -> String {
        var output = text

        if let amountToken {
            output = output.replacingOccurrences(of: amountToken, with: "")
        }

        ["kr", "nok", "usd", "eur", "$"].forEach { token in
            output = output.replacingOccurrences(of: token, with: "", options: [.caseInsensitive])
        }

        if let merchant {
            output = output.replacingOccurrences(
                of: "at \(merchant)",
                with: "",
                options: [.caseInsensitive]
            )
        }

        output = output
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return output.capitalized
    }

    private func categorize(text: String) -> ExpenseCategory {
        let keywordMap: [(ExpenseCategory, [String])] = [
            (.housing, ["rent", "mortgage", "apartment"]),
            (.transport, ["uber", "train", "bus", "taxi", "fuel", "parking"]),
            (.travel, ["flight", "hotel", "airbnb"]),
            (.groceries, ["grocery", "groceries", "rema", "kiwi", "coop"]),
            (.food, ["coffee", "dinner", "lunch", "breakfast", "food", "restaurant", "mcdonald"]),
            (.bills, ["invoice", "bill", "subscription", "electricity", "internet"]),
            (.shopping, ["shopping", "clothes", "ikea", "amazon"]),
            (.health, ["doctor", "pharmacy", "medicine", "gym"]),
            (.social, ["friends", "split", "drinks", "bar"])
        ]

        for (category, keywords) in keywordMap where keywords.contains(where: text.contains) {
            return category
        }

        return .uncategorized
    }
}
