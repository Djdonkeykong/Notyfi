import Foundation

struct ParsedExpenseDraft: Codable {
    var rawText: String
    var title: String
    var amount: Double
    var currencyCode: String
    var transactionKind: TransactionKind
    var category: ExpenseCategory
    var merchant: String?
    var note: String
    var confidence: ParsingConfidence
    var isAmountEstimated: Bool

    private enum CodingKeys: String, CodingKey {
        case rawText
        case title
        case amount
        case currencyCode
        case transactionKind
        case category
        case merchant
        case note
        case confidence
        case isAmountEstimated
    }

    init(
        rawText: String,
        title: String,
        amount: Double,
        currencyCode: String,
        transactionKind: TransactionKind = .expense,
        category: ExpenseCategory,
        merchant: String?,
        note: String,
        confidence: ParsingConfidence,
        isAmountEstimated: Bool = false
    ) {
        self.rawText = rawText
        self.title = title
        self.amount = amount
        self.currencyCode = currencyCode
        self.transactionKind = transactionKind
        self.category = category
        self.merchant = merchant
        self.note = note
        self.confidence = confidence
        self.isAmountEstimated = isAmountEstimated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        rawText = try container.decode(String.self, forKey: .rawText)
        title = try container.decode(String.self, forKey: .title)
        amount = try container.decode(Double.self, forKey: .amount)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        transactionKind = try container.decodeIfPresent(TransactionKind.self, forKey: .transactionKind) ?? .expense
        category = try container.decode(ExpenseCategory.self, forKey: .category)
        merchant = try container.decodeIfPresent(String.self, forKey: .merchant)
        note = try container.decode(String.self, forKey: .note)
        confidence = try container.decode(ParsingConfidence.self, forKey: .confidence)
        isAmountEstimated = try container.decodeIfPresent(Bool.self, forKey: .isAmountEstimated) ?? false
    }
}

protocol ExpenseParsingServicing {
    func parse(
        rawText: String,
        date: Date,
        currencyCode: String
    ) async throws -> ParsedExpenseDraft
}

enum ExpenseParsingServiceError: Error {
    case missingAPIKey
    case emptyModelResponse
}

struct OpenAIExpenseParsingService: ExpenseParsingServicing {
    enum RequestError: LocalizedError {
        case http(statusCode: Int, message: String)

        var errorDescription: String? {
            switch self {
            case let .http(_, message):
                return message
            }
        }

        var isRetryable: Bool {
            switch self {
            case let .http(statusCode, _):
                return statusCode == 408
                    || statusCode == 409
                    || statusCode == 429
                    || (500...599).contains(statusCode)
            }
        }
    }

    private let apiKey: String?
    private let model: String
    private let endpointURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(
        apiKey: String? = OpenAIExpenseParsingService.resolveAPIKey(),
        model: String = "gpt-4.1-mini",
        endpointURL: URL = URL(string: "https://api.openai.com/v1/chat/completions")!,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = model
        self.endpointURL = endpointURL
        self.session = session
    }

    private static func resolveAPIKey() -> String? {
        let environmentKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let environmentKey, !environmentKey.isEmpty {
            return environmentKey
        }

        let bundleKey = (Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let bundleKey,
           !bundleKey.isEmpty,
           bundleKey != "$(OPENAI_API_KEY)" {
            return bundleKey
        }

        let generatedKey = OpenAISecrets.apiKey
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !generatedKey.isEmpty {
            return generatedKey
        }

        return nil
    }

    func parse(
        rawText: String,
        date: Date,
        currencyCode: String
    ) async throws -> ParsedExpenseDraft {
        guard let apiKey, !apiKey.isEmpty else {
            throw ExpenseParsingServiceError.missingAPIKey
        }

        let requestBody = makeRequestBody(
            rawText: rawText,
            date: date,
            currencyCode: currencyCode
        )
        let payload = try JSONSerialization.data(withJSONObject: requestBody)
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = payload

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Unknown API error"
            throw RequestError.http(statusCode: httpResponse.statusCode, message: message)
        }

        let completion = try decoder.decode(ChatCompletionResponse.self, from: data)
        guard let content = completion.choices.first?.message.content else {
            throw ExpenseParsingServiceError.emptyModelResponse
        }

        let parsedData = Data(content.utf8)
        let parsedDraft = try decoder.decode(ParsedExpenseDraft.self, from: parsedData)

        return ParsedExpenseDraft(
            rawText: rawText,
            title: parsedDraft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: max(parsedDraft.amount, 0),
            currencyCode: parsedDraft.currencyCode.isEmpty ? currencyCode : parsedDraft.currencyCode,
            transactionKind: parsedDraft.transactionKind,
            category: parsedDraft.category,
            merchant: parsedDraft.merchant?.trimmingCharacters(in: .whitespacesAndNewlines),
            note: parsedDraft.note.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: parsedDraft.confidence,
            isAmountEstimated: parsedDraft.isAmountEstimated
        )
    }

    private func makeRequestBody(
        rawText: String,
        date: Date,
        currencyCode: String
    ) -> [String: Any] {
        let userContent = """
        Note: \(rawText)
        Date: \(ISO8601DateFormatter().string(from: date))
        Currency: \(currencyCode)

        Return one transaction JSON object. Infer a short title, amount as a positive number, transactionKind as expense/income, one allowed category, merchant if explicit, note as "" unless useful, confidence as certain/review/uncertain, and isAmountEstimated as true/false.
        Use transactionKind "income" for salary, freelance pay, refunds, reimbursements, gifts received, or money coming in. Use "expense" for spending, bills, purchases, subscriptions, or money going out.
        If no amount is written but the note mentions a concrete item/place, estimate a plausible amount in the given currency, set confidence "review", and set isAmountEstimated true. If there is not enough context to estimate, use amount 0, confidence "review", and isAmountEstimated false.
        """

        return [
            "model": model,
            "temperature": 0,
            "messages": [
                [
                    "role": "system",
                    "content": "You convert Norwegian or English personal finance notes into strict transaction JSON for a budgeting app."
                ],
                [
                    "role": "user",
                    "content": userContent
                ]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "notely_transaction_parse",
                    "strict": true,
                    "schema": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "rawText": ["type": "string"],
                            "title": ["type": "string"],
                            "amount": ["type": "number"],
                            "currencyCode": ["type": "string"],
                            "transactionKind": [
                                "type": "string",
                                "enum": TransactionKind.allCases.map(\.rawValue)
                            ],
                            "category": [
                                "type": "string",
                                "enum": ExpenseCategory.allCases.map(\.rawValue)
                            ],
                            "merchant": [
                                "anyOf": [
                                    ["type": "string"],
                                    ["type": "null"]
                                ]
                            ],
                            "note": ["type": "string"],
                            "confidence": [
                                "type": "string",
                                "enum": ParsingConfidence.allCases.map(\.rawValue)
                            ],
                            "isAmountEstimated": ["type": "boolean"]
                        ],
                        "required": [
                            "rawText",
                            "title",
                            "amount",
                            "currencyCode",
                            "transactionKind",
                            "category",
                            "merchant",
                            "note",
                            "confidence",
                            "isAmountEstimated"
                        ]
                    ]
                ]
            ]
        ]
    }
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}
