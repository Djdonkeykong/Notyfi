import Foundation

struct ParsedExpenseDraft: Decodable {
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
            throw NSError(
                domain: "OpenAIExpenseParsingService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
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
            category: parsedDraft.category,
            merchant: parsedDraft.merchant?.trimmingCharacters(in: .whitespacesAndNewlines),
            note: parsedDraft.note.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: parsedDraft.confidence
        )
    }

    private func makeRequestBody(
        rawText: String,
        date: Date,
        currencyCode: String
    ) -> [String: Any] {
        let categoryValues = ExpenseCategory.allCases
            .map(\.rawValue)
            .joined(separator: ", ")
        let userContent = """
        Parse this personal finance note into one transaction.

        Note: \(rawText)
        Date: \(ISO8601DateFormatter().string(from: date))
        Default currency: \(currencyCode)

        Rules:
        - Return one JSON object only.
        - Infer a concise title from the note.
        - Extract the numeric amount as a positive number.
        - Use one category from: \(categoryValues).
        - If no category clearly fits, use "uncategorized".
        - Extract merchant only when one is explicitly implied.
        - Keep note as "" unless there is extra context worth preserving.
        - confidence must be "certain" when the note is clear, otherwise "review" or "uncertain".
        """

        return [
            "model": model,
            "temperature": 0,
            "messages": [
                [
                    "role": "system",
                    "content": "You convert short personal finance notes into strict transaction JSON for a budgeting app."
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
                            ]
                        ],
                        "required": [
                            "rawText",
                            "title",
                            "amount",
                            "currencyCode",
                            "category",
                            "merchant",
                            "note",
                            "confidence"
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
