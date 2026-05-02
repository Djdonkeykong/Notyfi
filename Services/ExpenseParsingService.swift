import Foundation
import Supabase

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
    var isRecurring: Bool
    var recurringFrequency: RecurringFrequency?

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
        case isRecurring
        case recurringFrequency
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
        isAmountEstimated: Bool = false,
        isRecurring: Bool = false,
        recurringFrequency: RecurringFrequency? = nil
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
        self.isRecurring = isRecurring
        self.recurringFrequency = recurringFrequency
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
        isRecurring = try container.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? false
        recurringFrequency = try container.decodeIfPresent(RecurringFrequency.self, forKey: .recurringFrequency)
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

enum ExpenseParsingServiceError: LocalizedError {
    case serviceUnavailable
    case emptyModelResponse
    case noTransactionsFound

    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "AI parsing unavailable".notyfiLocalized
        case .emptyModelResponse:
            return "error.api.unknown".notyfiLocalized
        case .noTransactionsFound:
            return "Nothing to import".notyfiLocalized
        }
    }
}

struct OpenAIExpenseParsingService: ExpenseParsingServicing {
    enum RequestError: LocalizedError {
        case http(statusCode: Int, code: String?, message: String)

        var errorDescription: String? {
            switch self {
            case let .http(_, _, message):
                return message
            }
        }

        var isRetryable: Bool {
            switch self {
            case let .http(statusCode, _, _):
                return statusCode == 408
                    || statusCode == 409
                    || statusCode == 429
                    || (500...599).contains(statusCode)
            }
        }
    }

    private let functionName: String
    private let decoder = JSONDecoder()

    init(functionName: String = "parse-expense") {
        self.functionName = functionName
    }

    func parse(
        rawText: String,
        date: Date,
        currencyCode: String
    ) async throws -> ParsedExpenseDraft {
        let customCategories = CustomCategoryRegistry.shared.all.map {
            CustomCategoryHint(rawValue: $0.rawValue, title: $0.title)
        }
        let request = TextParseFunctionRequest(
            rawText: rawText,
            date: ISO8601DateFormatter().string(from: date),
            currencyCode: currencyCode,
            targetLanguageCode: currentAppLanguageContext().code,
            customCategories: customCategories
        )

        do {
            let response: TextParseFunctionResponse = try await SupabaseService.client.functions.invoke(
                functionName,
                options: FunctionInvokeOptions(body: request)
            )

            return sanitizeParsedDraft(
                response.entry,
                fallbackRawText: rawText,
                fallbackCurrencyCode: currencyCode
            )
        } catch let FunctionsError.httpError(statusCode, data) {
            throw try parsingError(
                statusCode: statusCode,
                data: data
            )
        } catch let error as FunctionsError {
            throw mapFunctionError(error)
        } catch {
            throw error
        }
    }

    func parse(
        imageData: Data,
        mimeType: String,
        date: Date,
        currencyCode: String
    ) async throws -> [ParsedExpenseDraft] {
        let customCategories = CustomCategoryRegistry.shared.all.map {
            CustomCategoryHint(rawValue: $0.rawValue, title: $0.title)
        }
        let request = ImageParseFunctionRequest(
            imageBase64: imageData.base64EncodedString(),
            mimeType: mimeType,
            date: ISO8601DateFormatter().string(from: date),
            currencyCode: currencyCode,
            targetLanguageCode: currentAppLanguageContext().code,
            customCategories: customCategories
        )

        do {
            let response: ImageParseFunctionResponse = try await SupabaseService.client.functions.invoke(
                functionName,
                options: FunctionInvokeOptions(body: request)
            )

            let drafts = response.entries.map { draft in
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
        } catch let FunctionsError.httpError(statusCode, data) {
            throw try parsingError(
                statusCode: statusCode,
                data: data
            )
        } catch let error as FunctionsError {
            throw mapFunctionError(error)
        } catch {
            throw error
        }
    }

    private func parsingError(
        statusCode: Int,
        data: Data
    ) throws -> Error {
        let payload = try? decoder.decode(FunctionErrorPayload.self, from: data)
        let message = payload?.error.message ?? "error.api.unknown".notyfiLocalized

        switch payload?.error.code {
        case "no_transactions_found":
            return ExpenseParsingServiceError.noTransactionsFound
        case "ai_service_unavailable":
            return ExpenseParsingServiceError.serviceUnavailable
        case "empty_model_response":
            return ExpenseParsingServiceError.emptyModelResponse
        default:
            return RequestError.http(
                statusCode: statusCode,
                code: payload?.error.code,
                message: message
            )
        }
    }

    private func mapFunctionError(_ error: FunctionsError) -> Error {
        switch error {
        case .relayError:
            return ExpenseParsingServiceError.serviceUnavailable
        default:
            return error
        }
    }

    private func currentAppLanguageContext() -> (code: String, name: String) {
        let selectedLanguage = NotyfiLanguage(
            rawValue: NotyfiLocale.storedLanguageCode()
        ) ?? .system

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
            title: trimmedTitle.isEmpty ? fallbackText : trimmedTitle,
            amount: max(draft.amount, 0),
            currencyCode: draft.currencyCode.isEmpty ? fallbackCurrencyCode : draft.currencyCode,
            transactionKind: draft.transactionKind,
            category: draft.category,
            merchant: draft.merchant?.trimmingCharacters(in: .whitespacesAndNewlines),
            note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: draft.confidence,
            isAmountEstimated: draft.isAmountEstimated,
            isRecurring: draft.isRecurring,
            recurringFrequency: draft.isRecurring ? (draft.recurringFrequency ?? .monthly) : nil
        )
    }
}

private struct CustomCategoryHint: Encodable {
    let rawValue: String
    let title: String
}

private struct TextParseFunctionRequest: Encodable {
    let kind = "text"
    let rawText: String
    let date: String
    let currencyCode: String
    let targetLanguageCode: String
    let customCategories: [CustomCategoryHint]
}

private struct ImageParseFunctionRequest: Encodable {
    let kind = "image"
    let imageBase64: String
    let mimeType: String
    let date: String
    let currencyCode: String
    let targetLanguageCode: String
    let customCategories: [CustomCategoryHint]
}

private struct TextParseFunctionResponse: Decodable {
    let entry: ParsedExpenseDraft
}

private struct ImageParseFunctionResponse: Decodable {
    let entries: [ParsedExpenseDraft]
}

private struct FunctionErrorPayload: Decodable {
    struct APIError: Decodable {
        let code: String
        let message: String
    }

    let error: APIError
}
