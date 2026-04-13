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

    func parse(
        imageData: Data,
        mimeType: String,
        date: Date,
        currencyCode: String
    ) async throws -> [ParsedExpenseDraft]
}

enum ExpenseParsingServiceError: Error {
    case missingAPIKey
    case emptyModelResponse
    case noTransactionsFound
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
    private let textModel: String
    private let imageModel: String
    private let endpointURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(
        apiKey: String? = OpenAIExpenseParsingService.resolveAPIKey(),
        textModel: String = "gpt-4.1-mini",
        imageModel: String = "gpt-4.1",
        endpointURL: URL = URL(string: "https://api.openai.com/v1/chat/completions")!,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.textModel = textModel
        self.imageModel = imageModel
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
            let message = String(data: data, encoding: .utf8) ?? "error.api.unknown".notyfiLocalized
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

    func parse(
        imageData: Data,
        mimeType: String,
        date: Date,
        currencyCode: String
    ) async throws -> [ParsedExpenseDraft] {
        guard let apiKey, !apiKey.isEmpty else {
            throw ExpenseParsingServiceError.missingAPIKey
        }

        let requestBody = makeImageRequestBody(
            imageData: imageData,
            mimeType: mimeType,
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
            let message = String(data: data, encoding: .utf8) ?? "error.api.unknown".notyfiLocalized
            throw RequestError.http(statusCode: httpResponse.statusCode, message: message)
        }

        let completion = try decoder.decode(ChatCompletionResponse.self, from: data)
        guard let content = completion.choices.first?.message.content else {
            throw ExpenseParsingServiceError.emptyModelResponse
        }

        let parsedData = Data(content.utf8)
        let parsedBatch = try decoder.decode(ParsedExpenseDraftBatch.self, from: parsedData)
        let drafts = parsedBatch.entries.map { draft in
            sanitizeParsedDraft(
                draft,
                fallbackRawText: draft.title,
                fallbackCurrencyCode: currencyCode
            )
        }

        guard !drafts.isEmpty else {
            throw ExpenseParsingServiceError.noTransactionsFound
        }

        return drafts
    }

    private func makeRequestBody(
        rawText: String,
        date: Date,
        currencyCode: String
    ) -> [String: Any] {
        let appLanguage = currentAppLanguageContext()
        let userContent = """
        Note: \(rawText)
        Date: \(ISO8601DateFormatter().string(from: date))
        Currency: \(currencyCode)
        Target language: \(appLanguage.name) (\(appLanguage.code))

        Return one transaction JSON object. Infer a short title, amount as a positive number, transactionKind as expense/income, one allowed category, merchant if explicit, note as "" unless useful, confidence as certain/review/uncertain, and isAmountEstimated as true/false.
        All natural-language fields must be written in \(appLanguage.name). Do not write English unless the target language is English.
        Write title and note in the target language above. Keep merchant in its original spelling when it is a brand or proper name.
        Keep transactionKind, category, confidence, and boolean fields as schema values.
        Use transactionKind "income" for salary, freelance pay, refunds, reimbursements, gifts received, or money coming in. Use "expense" for spending, bills, purchases, subscriptions, or money going out.
        If no amount is written but the note mentions a concrete item/place, estimate a plausible amount in the given currency, set confidence "review", and set isAmountEstimated true. If there is not enough context to estimate, use amount 0, confidence "review", and isAmountEstimated false.
        """

        return [
            "model": textModel,
            "temperature": 0,
            "messages": [
                [
                    "role": "system",
                    "content": "You convert personal finance notes into strict transaction JSON for a budgeting app. Always write natural-language output fields in the requested target language."
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

    private func makeImageRequestBody(
        imageData: Data,
        mimeType: String,
        date: Date,
        currencyCode: String
    ) -> [String: Any] {
        let appLanguage = currentAppLanguageContext()
        let base64Image = imageData.base64EncodedString()
        let imageDataURL = "data:\(mimeType);base64,\(base64Image)"
        let userPrompt = """
        Analyze this personal-finance photo and return one or more transaction JSON objects.
        Date context: \(ISO8601DateFormatter().string(from: date))
        Default currency: \(currencyCode)
        Target language: \(appLanguage.name) (\(appLanguage.code))

        Rules:
        - Return one entry per distinct money movement visible in the image.
        - A receipt, invoice, utility bill, order confirmation, brokerage trade, bank transfer, or payment confirmation is usually one entry.
        - If the image clearly contains multiple separate purchases, bills, trades, or transfers, return multiple entries.
        - Do not split a single receipt or bill into separate line-item transactions unless the image clearly shows separate payments.
        - rawText should be a concise journal note the user could have typed manually.
        - title should be short and clean.
        - amount must be positive.
        - Use the visible currency when explicit, otherwise use the default currency.
        - Use category uncategorized when no listed category fits well, including stock purchases or investment-related documents.
        - Use note for useful extra context from the image, such as billing period, share count, ticker, provider, or order details.
        - If any detail is unclear, keep the entry but lower confidence to review or uncertain.
        - All natural-language fields must be written in \(appLanguage.name). Do not write English unless the target language is English.
        - Write rawText, title, and note in the target language above.
        - Keep merchant in its original spelling when it is a brand or proper name.
        """

        return [
            "model": imageModel,
            "temperature": 0,
            "messages": [
                [
                    "role": "system",
                    "content": "You convert finance-related photos into strict transaction JSON for a budgeting app. Always write natural-language output fields in the requested target language."
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": userPrompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": imageDataURL,
                                "detail": "high"
                            ]
                        ]
                    ]
                ]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "notely_image_transaction_parse",
                    "strict": true,
                    "schema": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "entries": [
                                "type": "array",
                                "items": parsedExpenseDraftSchema()
                            ]
                        ],
                        "required": ["entries"]
                    ]
                ]
            ]
        ]
    }

    private func currentAppLanguageContext() -> (code: String, name: String) {
        let saved = UserDefaults.standard.string(forKey: LanguageManager.storageKey)
        let selectedLanguage = NotyfiLanguage(rawValue: saved ?? "") ?? .system

        if let localeCode = selectedLanguage.localeCode {
            return (localeCode, selectedLanguage.promptLanguageName)
        }

        let systemCode = Locale.preferredLanguages.first
            .flatMap { Locale(identifier: $0).language.languageCode?.identifier }

        let resolvedCode = systemCode ?? "en"
        let resolvedName = Locale(identifier: "en_US_POSIX")
            .localizedString(forLanguageCode: resolvedCode)?
            .capitalized
            ?? "English"

        return (resolvedCode, resolvedName)
    }

    private func parsedExpenseDraftSchema() -> [String: Any] {
        [
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
    }

    private func sanitizeParsedDraft(
        _ draft: ParsedExpenseDraft,
        fallbackRawText: String,
        fallbackCurrencyCode: String
    ) -> ParsedExpenseDraft {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRawText = draft.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackText = fallbackRawText.trimmingCharacters(in: .whitespacesAndNewlines)

        return ParsedExpenseDraft(
            rawText: trimmedRawText.isEmpty ? (trimmedTitle.isEmpty ? fallbackText : trimmedTitle) : trimmedRawText,
            title: trimmedTitle,
            amount: max(draft.amount, 0),
            currencyCode: draft.currencyCode.isEmpty ? fallbackCurrencyCode : draft.currencyCode,
            transactionKind: draft.transactionKind,
            category: draft.category,
            merchant: draft.merchant?.trimmingCharacters(in: .whitespacesAndNewlines),
            note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: draft.confidence,
            isAmountEstimated: draft.isAmountEstimated
        )
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

private struct ParsedExpenseDraftBatch: Decodable {
    let entries: [ParsedExpenseDraft]
}
