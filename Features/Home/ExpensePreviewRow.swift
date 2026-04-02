import SwiftUI

struct ExpensePreviewRow: View {
    let entry: ExpenseEntry

    private var supportingText: String? {
        if !entry.note.isEmpty {
            return entry.note
        }

        if let merchant = entry.merchant {
            return merchant
        }

        let raw = entry.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.caseInsensitiveCompare(title) == .orderedSame ? nil : raw
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(entry.title)
                    .font(.notely(.body, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)

                if let supportingText {
                    Text(supportingText)
                        .font(.notely(.subheadline))
                        .foregroundStyle(NotelyTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    CategoryTag(category: entry.category)

                    Text(entry.date.notelyTimeLabel())
                        .font(.notely(.caption))
                        .foregroundStyle(NotelyTheme.secondaryText)

                    if entry.confidence.needsReview {
                        Text("Needs review")
                            .font(.notely(.caption, weight: .medium))
                            .foregroundStyle(NotelyTheme.reviewTint)
                    }
                }
            }

            Spacer(minLength: 16)

            Text(entry.amount.formattedCurrency(code: entry.currencyCode))
                .font(.notely(.headline, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.82))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(NotelyTheme.elevatedSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(NotelyTheme.surfaceBorder, lineWidth: 1)
                }
        }
    }
}

private struct CategoryTag: View {
    let category: ExpenseCategory

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(category.tint)
                .frame(width: 7, height: 7)

            Text(category.title)
                .font(.notely(.caption, weight: .medium))
                .foregroundStyle(NotelyTheme.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.55))
        }
    }
}

#Preview {
    ExpensePreviewRow(
        entry: ExpenseEntry(
            rawText: "Coffee 49 kr",
            title: "Coffee",
            amount: 49,
            category: .food,
            merchant: "Talormade",
            date: Date(),
            note: "Quick stop before the train.",
            confidence: .certain
        )
    )
    .padding()
    .background(NotelyTheme.background)
}

