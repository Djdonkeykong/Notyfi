import SwiftUI

struct QuickCaptureComposer: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let showsPlaceholder: Bool
    let feedback: DraftComposerFeedback?
    let onTextChange: () -> Void

    private let editorLeadingOffset: CGFloat = -4
    private let editorTopOffset: CGFloat = -8
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

                TextEditor(text: $text)
                    .font(.notely(.body))
                    .foregroundStyle(.primary.opacity(0.86))
                    .scrollContentBackground(.hidden)
                    .focused(isFocused)
                    .frame(minHeight: 34, maxHeight: 120)
                    .padding(.leading, editorLeadingOffset)
                    .padding(.top, editorTopOffset)
            }

            VStack(alignment: .trailing, spacing: 5) {
                if let feedback {
                    Text(feedback.primaryText)
                        .font(.notely(.body, weight: .semibold))
                        .foregroundStyle(primaryFeedbackColor)
                        .multilineTextAlignment(.trailing)

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
        .onChange(of: text) { _, _ in
            onTextChange()
        }
    }
}

private struct QuickCaptureComposerPreviewWrapper: View {
    @State private var text = "Coffee 49"
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            NotelyTheme.background.ignoresSafeArea()
            VStack(alignment: .leading) {
                QuickCaptureComposer(
                    text: $text,
                    isFocused: $isFocused,
                    showsPlaceholder: false,
                    feedback: DraftComposerFeedback(
                        primaryText: "49 kr",
                        secondaryText: nil,
                        primaryColorName: .accent
                    ),
                    onTextChange: {}
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
