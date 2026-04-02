import SwiftUI
import UIKit

struct QuickCaptureComposer: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let showsPlaceholder: Bool
    let feedback: DraftComposerFeedback?
    let onTextChange: () -> Void
    let onEmptyBackspace: () -> Void

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

                ComposerTextView(
                    text: $text,
                    isFocused: focusBinding,
                    onEmptyBackspace: onEmptyBackspace
                )
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

    private var focusBinding: Binding<Bool> {
        Binding(
            get: { isFocused.wrappedValue },
            set: { isFocused.wrappedValue = $0 }
        )
    }
}

private struct ComposerTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let onEmptyBackspace: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused, onEmptyBackspace: onEmptyBackspace)
    }

    func makeUIView(context: Context) -> BackspaceAwareTextView {
        let textView = BackspaceAwareTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = UIColor.black.withAlphaComponent(0.86)
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = false
        textView.keyboardDismissMode = .interactive
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.onEmptyBackspace = {
            context.coordinator.handleEmptyBackspace()
        }
        return textView
    }

    func updateUIView(_ uiView: BackspaceAwareTextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        uiView.onEmptyBackspace = {
            context.coordinator.handleEmptyBackspace()
        }

        if isFocused, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding private var text: String
        @Binding private var isFocused: Bool
        private let onEmptyBackspace: () -> Void

        init(text: Binding<String>, isFocused: Binding<Bool>, onEmptyBackspace: @escaping () -> Void) {
            _text = text
            _isFocused = isFocused
            self.onEmptyBackspace = onEmptyBackspace
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isFocused = false
        }

        func handleEmptyBackspace() {
            onEmptyBackspace()
        }
    }
}

private final class BackspaceAwareTextView: UITextView {
    var onEmptyBackspace: (() -> Void)?

    override func deleteBackward() {
        if text.isEmpty {
            onEmptyBackspace?()
        }

        super.deleteBackward()
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
                    onTextChange: {},
                    onEmptyBackspace: {}
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
