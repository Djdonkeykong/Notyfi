import SwiftUI
import UIKit

struct JournalTextLineFrame: Equatable, Identifiable {
    let lineIndex: Int
    let minY: CGFloat
    let height: CGFloat

    var id: Int {
        lineIndex
    }
}

struct JournalLogTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var focusedEditor: JournalEditorTarget?
    @Binding var focusRequest: JournalEditorFocusRequest?

    let editorTarget: JournalEditorTarget
    let minHeight: CGFloat
    let isEditable: Bool
    let trailingInset: CGFloat
    let onTextChange: (String) -> Void
    let onLineFramesChange: ([JournalTextLineFrame]) -> Void

    func makeUIView(context: Context) -> EditableJournalTextView {
        let textView = EditableJournalTextView()
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: trailingInset)
        textView.textContainer.lineFragmentPadding = 0
        textView.font = .notelyBody
        textView.textColor = UIColor.label.withAlphaComponent(0.86)
        textView.tintColor = .label
        textView.isScrollEnabled = false
        textView.isEditable = isEditable
        textView.isSelectable = isEditable
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        return textView
    }

    func updateUIView(_ uiView: EditableJournalTextView, context: Context) {
        context.coordinator.parent = self
        uiView.isEditable = isEditable
        uiView.isSelectable = isEditable
        uiView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: trailingInset)

        if uiView.text != text {
            let cursorLocation = min(uiView.selectedRange.location, text.utf16.count)
            uiView.text = text

            if uiView.isFirstResponder {
                uiView.selectedRange = NSRange(location: cursorLocation, length: 0)
            }
        }

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

        context.coordinator.publishLineFrames(from: uiView)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: EditableJournalTextView,
        context: Context
    ) -> CGSize? {
        let width = max(proposal.width ?? uiView.bounds.width, 1)
        let measuredSize = uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )

        return CGSize(width: width, height: max(measuredSize.height, minHeight))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func applyCursorPlacement(
        _ placement: JournalEditorCursorPlacement,
        to textView: UITextView
    ) {
        let textLength = textView.text.utf16.count
        let cursorOffset: Int

        switch placement {
        case .start:
            cursorOffset = 0
        case .end:
            cursorOffset = textLength
        case .offset(let offset):
            cursorOffset = min(max(offset, 0), textLength)
        }

        textView.selectedRange = NSRange(location: cursorOffset, length: 0)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: JournalLogTextView
        var lastAppliedFocusToken: UUID?
        private var lastPublishedLineFrames: [JournalTextLineFrame] = []

        init(parent: JournalLogTextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if let editableTextView = textView as? EditableJournalTextView {
                EditableJournalTextView.activate(editableTextView)
            }

            if let focusRequest = parent.focusRequest,
               focusRequest.target != parent.editorTarget {
                parent.focusRequest = nil
            }

            parent.focusedEditor = parent.editorTarget
            publishLineFrames(from: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if let editableTextView = textView as? EditableJournalTextView {
                EditableJournalTextView.deactivate(editableTextView)
            }

            if parent.focusedEditor == parent.editorTarget {
                parent.focusedEditor = nil
            }

            lastAppliedFocusToken = nil
            publishLineFrames(from: textView)
        }

        func textViewDidChange(_ textView: UITextView) {
            let normalizedText = textView.text.replacingOccurrences(of: "\r\n", with: "\n")

            if parent.text != normalizedText {
                parent.text = normalizedText
            }

            parent.onTextChange(normalizedText)
            publishLineFrames(from: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            publishLineFrames(from: textView)
        }

        func publishLineFrames(from textView: UITextView) {
            let lineFrames = measureLineFrames(in: textView)
            guard lineFrames != lastPublishedLineFrames else {
                return
            }

            lastPublishedLineFrames = lineFrames

            DispatchQueue.main.async { [weak self] in
                self?.parent.onLineFramesChange(lineFrames)
            }
        }

        private func measureLineFrames(in textView: UITextView) -> [JournalTextLineFrame] {
            let text = textView.text ?? ""
            let lines = text.components(separatedBy: "\n")
            let layoutManager = textView.layoutManager
            let textContainer = textView.textContainer
            let lineHeight = max(textView.font?.lineHeight ?? 22, 22)
            let textStorage = textView.textStorage.string as NSString
            var frames: [JournalTextLineFrame] = []
            var characterLocation = 0

            layoutManager.ensureLayout(for: textContainer)

            for lineIndex in lines.indices {
                let lineLength = (lines[lineIndex] as NSString).length
                let lineRange = NSRange(location: characterLocation, length: lineLength)
                let frame: JournalTextLineFrame

                if lineLength > 0 {
                    let glyphRange = layoutManager.glyphRange(
                        forCharacterRange: lineRange,
                        actualCharacterRange: nil
                    )
                    let boundingRect = layoutManager.boundingRect(
                        forGlyphRange: glyphRange,
                        in: textContainer
                    )

                    frame = JournalTextLineFrame(
                        lineIndex: lineIndex,
                        minY: boundingRect.minY,
                        height: max(boundingRect.height, lineHeight)
                    )
                } else {
                    let safeLocation = min(characterLocation, textStorage.length)
                    let caretPosition = textView.position(
                        from: textView.beginningOfDocument,
                        offset: safeLocation
                    )
                    let caretRect = caretPosition.map {
                        textView.caretRect(for: $0)
                    } ?? .zero

                    frame = JournalTextLineFrame(
                        lineIndex: lineIndex,
                        minY: caretRect.minY,
                        height: lineHeight
                    )
                }

                frames.append(frame)
                characterLocation += lineLength + 1
            }

            if frames.isEmpty {
                frames.append(
                    JournalTextLineFrame(
                        lineIndex: 0,
                        minY: 0,
                        height: lineHeight
                    )
                )
            }

            return frames
        }
    }
}
