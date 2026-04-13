import CryptoKit
import Foundation

enum RecurringFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly:
            return "Weekly".notyfiLocalized
        case .monthly:
            return "Monthly".notyfiLocalized
        case .yearly:
            return "Yearly".notyfiLocalized
        }
    }

    func nextDate(
        after date: Date,
        interval: Int,
        calendar: Calendar
    ) -> Date? {
        switch self {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: max(1, interval), to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: max(1, interval), to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: max(1, interval), to: date)
        }
    }
}

struct RecurringTransaction: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var rawTextTemplate: String
    var amount: Double
    var currencyCode: String
    var transactionKind: TransactionKind
    var category: ExpenseCategory
    var merchant: String?
    var note: String
    var frequency: RecurringFrequency
    var interval: Int
    var startsAt: Date
    var nextOccurrenceAt: Date
    var endsAt: Date?
    var isActive: Bool
    var autopost: Bool
    var lastGeneratedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var scheduleSummary: String {
        let everyText: String
        if interval <= 1 {
            everyText = frequency.title
        } else {
            everyText = String(
                format: "Every %d %@".notyfiLocalized,
                interval,
                frequency.title.lowercased()
            )
        }

        if let endsAt {
            let formatter = DateFormatter()
            formatter.locale = NotyfiLocale.current()
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
            return "\(everyText) - \("Until".notyfiLocalized) \(formatter.string(from: endsAt))"
        }

        return everyText
    }

    func dueOccurrenceDates(
        upTo referenceDate: Date,
        calendar: Calendar,
        limit: Int = 36
    ) -> [Date] {
        guard isActive, autopost else {
            return []
        }

        let upperBound = min(referenceDate, endsAt ?? referenceDate)
        guard nextOccurrenceAt <= upperBound else {
            return []
        }

        var dueDates: [Date] = []
        var candidate = nextOccurrenceAt

        while candidate <= upperBound, dueDates.count < limit {
            dueDates.append(candidate)

            guard let nextCandidate = frequency.nextDate(
                after: candidate,
                interval: interval,
                calendar: calendar
            ) else {
                break
            }

            candidate = nextCandidate
        }

        return dueDates
    }

    func recurringEntry(
        for occurrenceDate: Date,
        createdAt: Date? = nil
    ) -> ExpenseEntry {
        let resolvedRawText = rawTextTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let instanceKey = Self.recurrenceInstanceKey(
            recurringTransactionID: id,
            occurrenceDate: occurrenceDate
        )

        return ExpenseEntry(
            id: Self.generatedEntryID(
                recurringTransactionID: id,
                occurrenceDate: occurrenceDate
            ),
            rawText: resolvedRawText.isEmpty ? resolvedTitle : resolvedRawText,
            title: resolvedTitle.isEmpty
                ? (resolvedRawText.isEmpty ? "Recurring entry".notyfiLocalized : resolvedRawText)
                : resolvedTitle,
            amount: amount,
            currencyCode: currencyCode,
            transactionKind: transactionKind,
            category: category,
            merchant: merchant,
            date: occurrenceDate,
            note: note,
            confidence: .certain,
            isAmountEstimated: false,
            createdAt: createdAt ?? occurrenceDate,
            recurringTransactionID: id,
            recurrenceInstanceKey: instanceKey
        )
    }

    func advancingPastDueOccurrences(
        _ dueDates: [Date],
        generatedAt date: Date,
        calendar: Calendar
    ) -> RecurringTransaction {
        guard let lastDueDate = dueDates.last else {
            return self
        }

        var updated = self
        updated.lastGeneratedAt = lastDueDate
        updated.updatedAt = date

        if let nextDate = frequency.nextDate(
            after: lastDueDate,
            interval: interval,
            calendar: calendar
        ) {
            updated.nextOccurrenceAt = nextDate

            if let endsAt, nextDate > endsAt {
                updated.isActive = false
            }
        } else {
            updated.isActive = false
        }

        return updated
    }

    static func recurrenceInstanceKey(
        recurringTransactionID: UUID,
        occurrenceDate: Date
    ) -> String {
        "\(recurringTransactionID.uuidString.lowercased())|\(occurrenceFormatter.string(from: occurrenceDate))"
    }

    static func generatedEntryID(
        recurringTransactionID: UUID,
        occurrenceDate: Date
    ) -> UUID {
        let key = recurrenceInstanceKey(
            recurringTransactionID: recurringTransactionID,
            occurrenceDate: occurrenceDate
        )
        let digest = Insecure.MD5.hash(data: Data(key.utf8))
        let bytes = Array(digest)
        let uuidBytes: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuidBytes)
    }

    static func nextScheduledDate(
        startsAt: Date,
        frequency: RecurringFrequency,
        interval: Int,
        onOrAfter baseline: Date,
        calendar: Calendar,
        limit: Int = 240
    ) -> Date? {
        var candidate = startsAt
        var attempts = 0

        while candidate < baseline, attempts < limit {
            guard let nextCandidate = frequency.nextDate(
                after: candidate,
                interval: interval,
                calendar: calendar
            ) else {
                return nil
            }

            candidate = nextCandidate
            attempts += 1
        }

        return candidate
    }

    private static let occurrenceFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

struct RecurringTransactionDraft: Identifiable, Equatable {
    let id: UUID
    var title: String
    var rawTextTemplate: String
    var amountText: String
    var currencyCode: String
    var transactionKind: TransactionKind
    var category: ExpenseCategory
    var merchant: String
    var note: String
    var frequency: RecurringFrequency
    var startsAt: Date
    var hasEndDate: Bool
    var endsAt: Date
    var isActive: Bool

    init(
        id: UUID = UUID(),
        title: String,
        rawTextTemplate: String,
        amountText: String,
        currencyCode: String,
        transactionKind: TransactionKind,
        category: ExpenseCategory,
        merchant: String = "",
        note: String = "",
        frequency: RecurringFrequency = .monthly,
        startsAt: Date = Date(),
        hasEndDate: Bool = false,
        endsAt: Date = Date(),
        isActive: Bool = true
    ) {
        self.id = id
        self.title = title
        self.rawTextTemplate = rawTextTemplate
        self.amountText = amountText
        self.currencyCode = currencyCode
        self.transactionKind = transactionKind
        self.category = category
        self.merchant = merchant
        self.note = note
        self.frequency = frequency
        self.startsAt = startsAt
        self.hasEndDate = hasEndDate
        self.endsAt = endsAt
        self.isActive = isActive
    }

    init(transaction: RecurringTransaction) {
        self.id = transaction.id
        self.title = transaction.title
        self.rawTextTemplate = transaction.rawTextTemplate
        self.amountText = transaction.amount == 0 ? "" : String(format: "%.2f", transaction.amount)
        self.currencyCode = transaction.currencyCode
        self.transactionKind = transaction.transactionKind
        self.category = transaction.category
        self.merchant = transaction.merchant ?? ""
        self.note = transaction.note
        self.frequency = transaction.frequency
        self.startsAt = transaction.startsAt
        self.hasEndDate = transaction.endsAt != nil
        self.endsAt = transaction.endsAt ?? transaction.startsAt
        self.isActive = transaction.isActive
    }

    init(entry: ExpenseEntry) {
        self.id = UUID()
        self.title = entry.title
        self.rawTextTemplate = entry.rawText
        self.amountText = entry.amount == 0 ? "" : String(format: "%.2f", entry.amount)
        self.currencyCode = entry.currencyCode
        self.transactionKind = entry.transactionKind
        self.category = entry.category
        self.merchant = entry.merchant ?? ""
        self.note = entry.note
        self.frequency = .monthly
        self.startsAt = entry.date
        self.hasEndDate = false
        self.endsAt = entry.date
        self.isActive = true
    }

    var parsedAmount: Double {
        max(0, Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0)
    }

    var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRawText = rawTextTemplate.trimmingCharacters(in: .whitespacesAndNewlines)

        return parsedAmount > 0
            && (!trimmedTitle.isEmpty || !trimmedRawText.isEmpty)
    }

    func recurringTransaction(
        existing: RecurringTransaction? = nil,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> RecurringTransaction {
        let resolvedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedRawText = rawTextTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedStartsAt = startsAt
        let resolvedEndsAt = hasEndDate ? max(endsAt, resolvedStartsAt) : nil
        let nextOccurrenceBaseline: Date

        if let lastGeneratedAt = existing?.lastGeneratedAt {
            nextOccurrenceBaseline = lastGeneratedAt.addingTimeInterval(1)
        } else {
            nextOccurrenceBaseline = resolvedStartsAt
        }

        let nextOccurrenceAt = RecurringTransaction.nextScheduledDate(
            startsAt: resolvedStartsAt,
            frequency: frequency,
            interval: 1,
            onOrAfter: nextOccurrenceBaseline,
            calendar: calendar
        ) ?? resolvedStartsAt

        var transaction = RecurringTransaction(
            id: existing?.id ?? id,
            title: resolvedTitle.isEmpty ? resolvedRawText : resolvedTitle,
            rawTextTemplate: resolvedRawText.isEmpty ? resolvedTitle : resolvedRawText,
            amount: parsedAmount,
            currencyCode: currencyCode,
            transactionKind: transactionKind,
            category: category,
            merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            frequency: frequency,
            interval: 1,
            startsAt: resolvedStartsAt,
            nextOccurrenceAt: nextOccurrenceAt,
            endsAt: resolvedEndsAt,
            isActive: isActive,
            autopost: true,
            lastGeneratedAt: existing?.lastGeneratedAt,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )

        if let resolvedEndsAt, transaction.nextOccurrenceAt > resolvedEndsAt {
            transaction.isActive = false
        }

        return transaction
    }
}
