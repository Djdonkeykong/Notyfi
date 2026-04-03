import SwiftUI
import UIKit

enum JournalEditorTarget: Hashable {
    case entry(UUID)
    case composer(Date)
}

enum JournalEditorCursorPlacement: Equatable {
    case start
    case end
    case offset(Int)
}

struct JournalEditorFocusRequest: Equatable {
    var target: JournalEditorTarget
    var cursorPlacement: JournalEditorCursorPlacement
    var token = UUID()
}

struct JournalEditorTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var focusedEditor: JournalEditorTarget?
    @Binding var focusRequest: JournalEditorFocusRequest?

    let editorTarget: JournalEditorTarget
    var textColor = UIColor.label.withAlphaComponent(0.86)
    var minHeight: CGFloat = 34
    var maxHeight: CGFloat?
    var onTextChange: (String) -> Void = { _ in }
    var onReturnKey: (String, String) -> Void = { _, _ in }
    var onBackspaceAtLeadingEdge: () -> Void = {}

    func makeUIView(context: Context) -> EditableJournalTextView {
        let textView = EditableJournalTextView()
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.font = .notelyBody
        textView.textColor = textColor
        textView.tintColor = .label
        textView.isScrollEnabled = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.onBackspaceAtLeadingEdge = {
            onBackspaceAtLeadingEdge()
        }

        return textView
    }

    func updateUIView(_ uiView: EditableJournalTextView, context: Context) {
        context.coordinator.parent = self
        uiView.onBackspaceAtLeadingEdge = {
            onBackspaceAtLeadingEdge()
        }

        if uiView.text != text {
            uiView.text = text

            if uiView.isFirstResponder {
                applyCursorPlacement(.offset(min(uiView.selectedRange.location, text.utf16.count)), to: uiView)
            }
        }

        uiView.textColor = textColor
        uiView.font = .notelyBody
        uiView.isScrollEnabled = shouldScroll(uiView: uiView)

        if let focusRequest, focusRequest.target == editorTarget {
            if context.coordinator.lastAppliedFocusToken != focusRequest.token {
                if uiView.isFirstResponder || uiView.becomeFirstResponder() {
                    applyCursorPlacement(focusRequest.cursorPlacement, to: uiView)
                    context.coordinator.lastAppliedFocusToken = focusRequest.token
                } else {
                    let coordinator = context.coordinator

                    DispatchQueue.main.async { [weak uiView] in
                        guard
                            let uiView,
                            coordinator.parent.focusRequest?.token == focusRequest.token,
                            coordinator.parent.focusRequest?.target == editorTarget,
                            !uiView.isFirstResponder,
                            uiView.becomeFirstResponder()
                        else {
                            return
                        }

                        applyCursorPlacement(focusRequest.cursorPlacement, to: uiView)
                        coordinator.lastAppliedFocusToken = focusRequest.token
                    }
                }
            }
        } else if uiView.isFirstResponder, focusedEditor != editorTarget {
            uiView.resignFirstResponder()
            context.coordinator.lastAppliedFocusToken = nil
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: EditableJournalTextView,
        context: Context
    ) -> CGSize? {
        let width = max(proposal.width ?? uiView.bounds.width, 1)
        let targetSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        let measuredSize = uiView.sizeThatFits(targetSize)
        let height = min(max(measuredSize.height, minHeight), maxHeight ?? measuredSize.height)

        return CGSize(width: width, height: height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func shouldScroll(uiView: EditableJournalTextView) -> Bool {
        guard let maxHeight else {
            return false
        }

        guard uiView.bounds.width > 1 else {
            return false
        }

        let measuredHeight = uiView.sizeThatFits(
            CGSize(width: uiView.bounds.width, height: .greatestFiniteMagnitude)
        ).height

        return measuredHeight > maxHeight
    }

    private func applyCursorPlacement(
        _ placement: JournalEditorCursorPlacement,
        to uiView: UITextView
    ) {
        let textLength = uiView.text.utf16.count
        let targetOffset: Int

        switch placement {
        case .start:
            targetOffset = 0
        case .end:
            targetOffset = textLength
        case .offset(let offset):
            targetOffset = min(max(offset, 0), textLength)
        }

        uiView.selectedRange = NSRange(location: targetOffset, length: 0)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: JournalEditorTextView
        var lastAppliedFocusToken: UUID?

        init(parent: JournalEditorTextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.focusedEditor = parent.editorTarget
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if parent.focusedEditor == parent.editorTarget {
                parent.focusedEditor = nil
            }

            lastAppliedFocusToken = nil
        }

        func textViewDidChange(_ textView: UITextView) {
            let normalizedText = textView.text.replacingOccurrences(of: "\r\n", with: "\n")

            if parent.text != normalizedText {
                parent.text = normalizedText
            }

            parent.onTextChange(normalizedText)
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText replacement: String
        ) -> Bool {
            guard replacement == "\n" else {
                return true
            }

            let currentText = textView.text ?? ""
            guard
                let textRange = Range(range, in: currentText)
            else {
                return false
            }

            let leadingText = String(currentText[..<textRange.lowerBound])
            let trailingText = String(currentText[textRange.upperBound...])
            parent.onReturnKey(leadingText, trailingText)

            return false
        }
    }
}

final class EditableJournalTextView: UITextView {
    var onBackspaceAtLeadingEdge: (() -> Void)?

    override func deleteBackward() {
        if selectedRange.location == 0, selectedRange.length == 0 {
            onBackspaceAtLeadingEdge?()
            return
        }

        super.deleteBackward()
    }
}

private extension UIFont {
    static var notelyBody: UIFont {
        let descriptor = UIFont.systemFont(ofSize: 17, weight: .regular).fontDescriptor

        if let roundedDescriptor = descriptor.withDesign(.rounded) {
            return UIFont(descriptor: roundedDescriptor, size: 17)
        }

        return UIFont.systemFont(ofSize: 17, weight: .regular)
    }
}
