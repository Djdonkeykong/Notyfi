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

struct JournalLogLineEdit {
    let lineIndex: Int
    let leadingText: String
    let trailingText: String
}

struct JournalLogTextView: UIViewRepresentable {
    static let paragraphSpacing: CGFloat = 29
    static let estimatedLineHeight: CGFloat = 22

    @Binding var text: String
    @Binding var focusedEditor: JournalEditorTarget?
    @Binding var focusRequest: JournalEditorFocusRequest?
    @Binding var cursorLineIndex: Int

    let editorTarget: JournalEditorTarget
    let minHeight: CGFloat
    let isEditable: Bool
    let trailingInset: CGFloat
    let onTextChange: (String) -> Void
    let onReturnKey: (JournalLogLineEdit) -> Void
    let onBackspaceAtLineStart: (Int) -> Void
    let onLineFramesChange: ([JournalTextLineFrame]) -> Void

    private static var textAttributes: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1
        paragraphStyle.paragraphSpacing = Self.paragraphSpacing
        paragraphStyle.lineBreakMode = .byWordWrapping

        return [
            .font: UIFont.notyfiBody,
            .foregroundColor: UIColor.label.withAlphaComponent(0.86),
            .paragraphStyle: paragraphStyle
        ]
    }

    func makeUIView(context: Context) -> EditableJournalTextView {
        let textView = EditableJournalTextView()
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: trailingInset)
        textView.textContainer.lineFragmentPadding = 0
        textView.font = .notyfiBody
        textView.textColor = UIColor.label.withAlphaComponent(0.86)
        textView.tintColor = UIColor(
            red: 0.26,
            green: 0.56,
            blue: 0.96,
            alpha: 1
        )
        textView.autocorrectionType = .default
        textView.spellCheckingType = .default
        textView.smartQuotesType = .default
        textView.smartDashesType = .default
        textView.smartInsertDeleteType = .default
        if #available(iOS 17.0, *) {
            textView.inlinePredictionType = .no
        }
        textView.typingAttributes = Self.textAttributes
        textView.isScrollEnabled = false
        textView.isEditable = isEditable
        textView.isSelectable = isEditable
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.onLayoutUpdate = { [weak coordinator = context.coordinator, weak textView] in
            guard let textView else {
                return
            }

            coordinator?.publishLineFrames(from: textView)
        }

        return textView
    }

    func updateUIView(_ uiView: EditableJournalTextView, context: Context) {
        context.coordinator.parent = self
        uiView.isEditable = isEditable
        uiView.isSelectable = isEditable
        uiView.autocorrectionType = .default
        uiView.spellCheckingType = .default
        uiView.smartQuotesType = .default
        uiView.smartDashesType = .default
        uiView.smartInsertDeleteType = .default
        if #available(iOS 17.0, *) {
            uiView.inlinePredictionType = .no
        }
        uiView.typingAttributes = Self.textAttributes
        uiView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: trailingInset)
        uiView.onLayoutUpdate = { [weak coordinator = context.coordinator, weak uiView] in
            guard let uiView else {
                return
            }

            coordinator?.publishLineFrames(from: uiView)
        }

        if uiView.text != text {
            let cursorLocation = min(uiView.selectedRange.location, text.utf16.count)
            uiView.attributedText = NSAttributedString(
                string: text,
                attributes: Self.textAttributes
            )

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
            publishCursorLineIndex(from: textView)
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
            publishCursorLineIndex(from: textView)
            publishLineFrames(from: textView)
        }

        func textViewDidChange(_ textView: UITextView) {
            let normalizedText = textView.text.replacingOccurrences(of: "\r\n", with: "\n")

            if parent.text != normalizedText {
                parent.text = normalizedText
            }

            parent.onTextChange(normalizedText)
            publishCursorLineIndex(from: textView)
            publishLineFrames(from: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            publishCursorLineIndex(from: textView)
            publishLineFrames(from: textView)
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText replacement: String
        ) -> Bool {
            let currentText = textView.text ?? ""

            if replacement == "\n",
               let edit = lineEdit(
                   in: currentText,
                   range: range
               ) {
                parent.onReturnKey(edit)
                return false
            }

            if replacement.isEmpty,
               range.length == 1,
               range.location < (currentText as NSString).length,
               isDeletingLineBreak(
                   in: currentText,
                   range: range
               ) {
                let lineIndex = lineIndexAfterDeletedLineBreak(
                    in: currentText,
                    range: range
                )
                parent.onBackspaceAtLineStart(lineIndex)
                return false
            }

            return true
        }

        private func publishCursorLineIndex(from textView: UITextView) {
            let nsText = (textView.text ?? "") as NSString
            let cursorLocation = min(
                max(textView.selectedRange.location, 0),
                nsText.length
            )
            let textBeforeCursor = nsText.substring(to: cursorLocation)
            let lineIndex = textBeforeCursor.reduce(into: 0) { count, character in
                if character == "\n" {
                    count += 1
                }
            }

            if parent.cursorLineIndex != lineIndex {
                parent.cursorLineIndex = lineIndex
            }
        }

        func publishLineFrames(from textView: UITextView) {
            guard textView.bounds.width > 10 else {
                return
            }
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
            let lineHeight = max(
                textView.font?.lineHeight ?? JournalLogTextView.estimatedLineHeight,
                JournalLogTextView.estimatedLineHeight
            )
            let textStorage = textView.textStorage.string as NSString
            var frames: [JournalTextLineFrame] = []
            var characterLocation = 0

            layoutManager.ensureLayout(for: textContainer)

            for lineIndex in lines.indices {
                let lineLength = (lines[lineIndex] as NSString).length
                let safeLocation = min(characterLocation, textStorage.length)
                let lineStartPosition = textView.position(
                    from: textView.beginningOfDocument,
                    offset: safeLocation
                )
                let caretRect = lineStartPosition.map {
                    textView.caretRect(for: $0)
                } ?? .zero
                let lineRange = NSRange(location: safeLocation, length: lineLength)
                let frame: JournalTextLineFrame

                if lineLength > 0 {
                    let glyphRange = layoutManager.glyphRange(
                        forCharacterRange: lineRange,
                        actualCharacterRange: nil
                    )
                    let lineFragmentRect = layoutManager.lineFragmentRect(
                        forGlyphAt: glyphRange.location,
                        effectiveRange: nil,
                        withoutAdditionalLayout: true
                    )
                    let boundingRect = layoutManager.boundingRect(
                        forGlyphRange: glyphRange,
                        in: textContainer
                    )
                    let lineTopY = min(caretRect.minY, lineFragmentRect.minY)

                    frame = JournalTextLineFrame(
                        lineIndex: lineIndex,
                        minY: lineTopY,
                        height: max(
                            boundingRect.maxY - lineTopY,
                            lineFragmentRect.height,
                            lineHeight
                        )
                    )
                } else {
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

        private func lineEdit(
            in text: String,
            range: NSRange
        ) -> JournalLogLineEdit? {
            guard let textRange = Range(range, in: text) else {
                return nil
            }

            let nsText = text as NSString
            let selectedText = nsText.substring(with: range)
            guard !selectedText.contains("\n") else {
                return nil
            }

            let lineIndex = text[..<textRange.lowerBound].reduce(into: 0) { count, character in
                if character == "\n" {
                    count += 1
                }
            }

            let lineStart = text[..<textRange.lowerBound].lastIndex(of: "\n").map {
                text.index(after: $0)
            } ?? text.startIndex
            let lineEnd = text[textRange.upperBound...].firstIndex(of: "\n") ?? text.endIndex
            let leadingText = String(text[lineStart..<textRange.lowerBound])
            let trailingText = String(text[textRange.upperBound..<lineEnd])

            return JournalLogLineEdit(
                lineIndex: lineIndex,
                leadingText: leadingText,
                trailingText: trailingText
            )
        }

        private func isDeletingLineBreak(
            in text: String,
            range: NSRange
        ) -> Bool {
            let nsText = text as NSString
            return nsText.substring(with: range) == "\n"
        }

        private func lineIndexAfterDeletedLineBreak(
            in text: String,
            range: NSRange
        ) -> Int {
            let nsText = text as NSString
            let prefixLength = min(range.location + range.length, nsText.length)
            let prefix = nsText.substring(to: prefixLength)

            return prefix.reduce(into: 0) { count, character in
                if character == "\n" {
                    count += 1
                }
            }
        }
    }
}
