import SwiftUI

struct ExpensePreviewRow: View {
    let entry: ExpenseEntry
    @Binding var focusedEditor: JournalEditorTarget?
    @Binding var focusRequest: JournalEditorFocusRequest?
    let isEditable: Bool
    let isAccessoryTapEnabled: Bool
    let onTextChange: (String) -> Void
    let onSplitText: (String, String) -> Void
    let onMergeBackward: () -> Void
    let onAccessoryTap: () -> Void

    @State private var draftText: String

    private let trailingColumnWidth: CGFloat = 96
    private let trailingSecondaryHeight: CGFloat = 16

    init(
        entry: ExpenseEntry,
        focusedEditor: Binding<JournalEditorTarget?> = .constant(nil),
        focusRequest: Binding<JournalEditorFocusRequest?> = .constant(nil),
        isEditable: Bool = true,
        isAccessoryTapEnabled: Bool = true,
        onTextChange: @escaping (String) -> Void = { _ in },
        onSplitText: @escaping (String, String) -> Void = { _, _ in },
        onMergeBackward: @escaping () -> Void = {},
        onAccessoryTap: @escaping () -> Void = {}
    ) {
        self.entry = entry
        _focusedEditor = focusedEditor
        _focusRequest = focusRequest
        self.isEditable = isEditable
        self.isAccessoryTapEnabled = isAccessoryTapEnabled
        self.onTextChange = onTextChange
        self.onSplitText = onSplitText
        self.onMergeBackward = onMergeBackward
        self.onAccessoryTap = onAccessoryTap
        _draftText = State(initialValue: entry.rawText)
    }

    private var trailingPrimary: String {
        if isDraftEmpty {
            return ""
        }

        if entry.amount == 0 {
            return entry.confidence == .review ? "Review" : "Thinking"
        }

        if entry.isAmountEstimated {
            return signedAmountText
        }

        if entry.confidence.needsReview {
            return "Review"
        }

        return signedAmountText
    }

    private var trailingSecondary: String? {
        if isDraftEmpty {
            return nil
        }

        if entry.confidence.needsReview {
            if entry.amount == 0 {
                return nil
            }

            if entry.category != .uncategorized {
                return entry.category.title
            }

            if entry.transactionKind == .income {
                return TransactionKind.income.title
            }

            return entry.amount > 0 ? signedAmountText : nil
        }

        if entry.category != .uncategorized {
            return entry.category.title
        }

        if entry.transactionKind == .income {
            return TransactionKind.income.title
        }

        return entry.merchant
    }

    private var trailingPrimaryColor: Color {
        if entry.amount == 0 {
            return NotelyTheme.secondaryText
        }

        if entry.confidence.needsReview, !entry.isAmountEstimated {
            return NotelyTheme.secondaryText
        }

        return entry.transactionKind == .income
            ? Color(red: 0.28, green: 0.71, blue: 0.45)
            : Color(red: 0.90, green: 0.36, blue: 0.34)
    }

    private var signedAmountText: String {
        let formattedAmount = entry.amount.formattedCurrency(code: entry.currencyCode)
        let signedAmount = entry.transactionKind == .income ? "+\(formattedAmount)" : "-\(formattedAmount)"
        return entry.isAmountEstimated ? "\(signedAmount)*" : signedAmount
    }

    private var trailingSecondaryDisplay: String {
        trailingSecondary ?? " "
    }

    private var isDraftEmpty: Bool {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isProcessingStatus: Bool {
        !isDraftEmpty && entry.amount == 0
    }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            JournalEditorTextView(
                text: $draftText,
                focusedEditor: $focusedEditor,
                focusRequest: $focusRequest,
                editorTarget: .entry(entry.id),
                onTextChange: { normalizedText in
                    onTextChange(normalizedText)
                },
                onReturnKey: { leadingText, trailingText in
                    onSplitText(leadingText, trailingText)
                },
                onBackspaceAtLeadingEdge: {
                    onMergeBackward()
                }
            )
                .allowsHitTesting(isEditable)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: entry.rawText) { _, newValue in
                    if draftText != newValue {
                        draftText = newValue
                    }
                }

            Button(action: onAccessoryTap) {
                VStack(alignment: .trailing, spacing: 5) {
                    if isProcessingStatus {
                        JournalProcessingStatusText(activityText: draftText)
                            .font(.notely(.body, weight: .semibold))
                            .foregroundStyle(trailingPrimaryColor)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                    } else {
                        Text(trailingPrimary)
                            .font(.notely(.body, weight: .semibold))
                            .foregroundStyle(trailingPrimaryColor)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                    }

                    Text(trailingSecondaryDisplay)
                        .font(.notely(.footnote))
                        .foregroundStyle(NotelyTheme.tertiaryText)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(height: trailingSecondaryHeight, alignment: .top)
                        .opacity(trailingSecondary == nil ? 0 : 1)
                }
                .frame(width: trailingColumnWidth, alignment: .topTrailing)
                .padding(.top, 1)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!isDraftEmpty && isAccessoryTapEnabled)
            .opacity(isDraftEmpty ? 0 : 1)
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
