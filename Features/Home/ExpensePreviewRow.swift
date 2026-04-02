import SwiftUI

struct ExpensePreviewRow: View {
    let entry: ExpenseEntry
    @Binding var focusedEditor: JournalEditorTarget?
    @Binding var focusRequest: JournalEditorFocusRequest?
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
        onTextChange: @escaping (String) -> Void = { _ in },
        onSplitText: @escaping (String, String) -> Void = { _, _ in },
        onMergeBackward: @escaping () -> Void = {},
        onAccessoryTap: @escaping () -> Void = {}
    ) {
        self.entry = entry
        _focusedEditor = focusedEditor
        _focusRequest = focusRequest
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
            return "Thinking"
        }

        if entry.confidence.needsReview {
            return "Review"
        }

        return entry.amount.formattedCurrency(code: entry.currencyCode)
    }

    private var trailingSecondary: String? {
        if isDraftEmpty {
            return nil
        }

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

    private var trailingSecondaryDisplay: String {
        trailingSecondary ?? " "
    }

    private var isDraftEmpty: Bool {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: entry.rawText) { _, newValue in
                    if draftText != newValue {
                        draftText = newValue
                    }
                }

            Button(action: onAccessoryTap) {
                VStack(alignment: .trailing, spacing: 5) {
                    Text(trailingPrimary)
                        .font(.notely(.body))
                        .foregroundStyle(trailingPrimaryColor)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)

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
            .disabled(isDraftEmpty)
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
