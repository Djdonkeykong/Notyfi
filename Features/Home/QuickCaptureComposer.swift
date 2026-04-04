import SwiftUI

struct QuickCaptureComposer: View {
    @Binding var text: String
    @Binding var focusedEditor: JournalEditorTarget?
    @Binding var focusRequest: JournalEditorFocusRequest?
    let editorTarget: JournalEditorTarget
    let isEditable: Bool
    let showsPlaceholder: Bool
    let feedback: DraftComposerFeedback?
    let onTextChange: (String) -> Void
    let onSplitText: (String, String) -> Void
    let onMergeBackward: () -> Void

    private let placeholderLeadingOffset: CGFloat = 1
    private let placeholderTopOffset: CGFloat = 0

    private var primaryFeedbackColor: Color {
        switch feedback?.primaryColorName {
        case .accent:
            return Color(red: 0.26, green: 0.56, blue: 0.96)
        case .neutral, .none:
            return NotelyTheme.secondaryText
        }
    }

    private var isProcessingFeedback: Bool {
        feedback?.primaryColorName == .neutral
    }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack(alignment: .topLeading) {
                if showsPlaceholder && text.isEmpty {
                    Text("Start typing your money notes...")
                        .font(.notely(.body))
                        .foregroundStyle(NotelyTheme.tertiaryText)
                        .padding(.top, placeholderTopOffset)
                        .padding(.leading, placeholderLeadingOffset)
                        .allowsHitTesting(false)
                }

                JournalEditorTextView(
                    text: $text,
                    focusedEditor: $focusedEditor,
                    focusRequest: $focusRequest,
                    editorTarget: editorTarget,
                    maxHeight: 120,
                    onTextChange: { newText in
                        onTextChange(newText)
                    },
                    onReturnKey: { leadingText, trailingText in
                        onSplitText(leadingText, trailingText)
                    },
                    onBackspaceAtLeadingEdge: {
                        onMergeBackward()
                    }
                )
                .allowsHitTesting(isEditable)
            }

            VStack(alignment: .trailing, spacing: 5) {
                if let feedback {
                    if isProcessingFeedback {
                        JournalProcessingStatusText(activityText: text)
                            .font(.notely(.body, weight: .semibold))
                            .foregroundStyle(primaryFeedbackColor)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text(feedback.primaryText)
                            .font(.notely(.body, weight: .semibold))
                            .foregroundStyle(primaryFeedbackColor)
                            .multilineTextAlignment(.trailing)
                    }

                    if let secondary = feedback.secondaryText {
                        Text(secondary)
                            .font(.notely(.footnote))
                            .foregroundStyle(NotelyTheme.tertiaryText)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .frame(minWidth: 74, alignment: .trailing)
            .padding(.top, 3)
        }
        .padding(.vertical, 4)
    }
}

private struct QuickCaptureComposerPreviewWrapper: View {
    @State private var text = "Coffee 49"
    @State private var focusedEditor: JournalEditorTarget? = .composer(
        Calendar.current.startOfDay(for: Date())
    )
    @State private var focusRequest: JournalEditorFocusRequest? = JournalEditorFocusRequest(
        target: .composer(Calendar.current.startOfDay(for: Date())),
        cursorPlacement: .end
    )

    var body: some View {
        ZStack {
            NotelyTheme.background.ignoresSafeArea()
            VStack(alignment: .leading) {
                QuickCaptureComposer(
                    text: $text,
                    focusedEditor: $focusedEditor,
                    focusRequest: $focusRequest,
                    editorTarget: .composer(Calendar.current.startOfDay(for: Date())),
                    isEditable: true,
                    showsPlaceholder: false,
                    feedback: DraftComposerFeedback(
                        primaryText: "49 kr",
                        secondaryText: nil,
                        primaryColorName: .accent
                    ),
                    onTextChange: { _ in },
                    onSplitText: { _, _ in },
                    onMergeBackward: {}
                )
                .padding(20)
                Spacer()
            }
        }
    }
}

#Preview {
    QuickCaptureComposerPreviewWrapper()
}
