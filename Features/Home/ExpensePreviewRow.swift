import SwiftUI

struct ExpensePreviewRow: View {
    let entry: ExpenseEntry

    private var leadingText: String {
        let raw = entry.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? entry.title : raw
    }

    private var trailingPrimary: String {
        if entry.amount == 0 {
            return "Thinking"
        }

        if entry.confidence.needsReview {
            return "Review"
        }

        return entry.amount.formattedCurrency(code: entry.currencyCode)
    }

    private var trailingSecondary: String? {
        if entry.confidence.needsReview {
            return entry.amount > 0 ? entry.amount.formattedCurrency(code: entry.currencyCode) : nil
        }

        if let merchant = entry.merchant, !merchant.isEmpty {
            return merchant
        }

        return nil
    }

    private var trailingPrimaryColor: Color {
        if entry.amount == 0 || entry.confidence.needsReview {
            return NotelyTheme.secondaryText
        }

        return Color(red: 0.26, green: 0.56, blue: 0.96)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Text(leadingText)
                .font(.notely(.body))
                .foregroundStyle(.primary.opacity(0.86))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 5) {
                Text(trailingPrimary)
                    .font(.notely(.body, weight: .semibold))
                    .foregroundStyle(trailingPrimaryColor)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: true, vertical: false)

                if let trailingSecondary {
                    Text(trailingSecondary)
                        .font(.notely(.footnote))
                        .foregroundStyle(NotelyTheme.tertiaryText)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.top, 1)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ExpensePreviewRow(
        entry: ExpenseEntry(
            rawText: "Coffee 49 kr at Talormade",
            title: "Coffee",
            amount: 49,
            category: .food,
            merchant: "Talormade",
            date: Date(),
            note: "",
            confidence: .certain
        )
    )
    .padding()
    .background(NotelyTheme.background)
}
