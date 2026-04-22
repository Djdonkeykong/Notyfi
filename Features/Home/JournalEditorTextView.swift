import UIKit

enum JournalEditorTarget: Hashable {
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

final class EditableJournalTextView: UITextView {
    private static weak var activeEditor: EditableJournalTextView?
    private static var lastDeleteTimestamp = Date.distantPast
    private static var shouldBridgeBackspace = false
    private static var pendingBridgeAttempts = 0
    private var dictatedRange: NSRange?

    var onBackspaceAtLeadingEdge: (() -> Void)?
    var onLayoutUpdate: (() -> Void)?

    static func activate(_ editor: EditableJournalTextView) {
        activeEditor = editor
    }

    static func deactivate(_ editor: EditableJournalTextView) {
        guard activeEditor === editor else {
            return
        }

        activeEditor = nil
        shouldBridgeBackspace = false
        pendingBridgeAttempts = 0
    }

    static func resignActiveEditor() {
        shouldBridgeBackspace = false
        pendingBridgeAttempts = 0
        activeEditor?.resignFirstResponder()
    }

    static func beginActiveDictationSession() {
        activeEditor?.beginDictationSession()
    }

    static func updateActiveDictationTranscript(_ transcript: String) {
        activeEditor?.updateDictationTranscript(transcript)
    }

    static func endActiveDictationSession() {
        activeEditor?.endDictationSession()
    }

    override func deleteBackward() {
        let now = Date()
        let isLikelyKeyRepeat = now.timeIntervalSince(Self.lastDeleteTimestamp) < 0.18
        Self.lastDeleteTimestamp = now

        if selectedRange.location == 0, selectedRange.length == 0 {
            guard let onBackspaceAtLeadingEdge else {
                Self.shouldBridgeBackspace = false
                Self.pendingBridgeAttempts = 0
                super.deleteBackward()
                return
            }

            Self.shouldBridgeBackspace = isLikelyKeyRepeat
            onBackspaceAtLeadingEdge()

            guard Self.shouldBridgeBackspace else {
                return
            }

            Self.pendingBridgeAttempts = 12
            Self.dispatchBridgedBackspace()

            return
        }

        Self.shouldBridgeBackspace = false
        super.deleteBackward()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayoutUpdate?()
    }

    private func performDeferredScroll(to rect: CGRect) {
        super.scrollRectToVisible(rect, animated: false)
    }

    override func scrollRectToVisible(_ rect: CGRect, animated: Bool) {
        // UIKit fires this synchronously when the cursor moves to a new line, before
        // SwiftUI has committed the grown content size. Deferring to the next runloop
        // tick ensures the CATransaction has fully committed the new layout before the
        // outer SwiftUI ScrollView processes the scroll, eliminating the jump-then-snap.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isFirstResponder else { return }
            self.performDeferredScroll(to: rect)
        }
    }

    override func caretRect(for position: UITextPosition) -> CGRect {
        var rect = super.caretRect(for: position)
        let targetHeight = font?.lineHeight ?? UIFont.notyfiBody.lineHeight

        if rect.height > targetHeight * 1.2 {
            rect.size.height = targetHeight
        }

        return rect
    }

    override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        let rects = super.selectionRects(for: range)
        let targetHeight = font?.lineHeight ?? UIFont.notyfiBody.lineHeight
        return rects.map { r in
            guard (r.containsStart || r.containsEnd) && r.rect.height > targetHeight * 1.4 else {
                return r
            }
            return ClampedSelectionRect(
                source: r,
                rect: CGRect(x: r.rect.minX, y: r.rect.minY, width: r.rect.width, height: targetHeight)
            )
        }
    }

    private static func dispatchBridgedBackspace() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            guard shouldBridgeBackspace else {
                pendingBridgeAttempts = 0
                return
            }

            guard pendingBridgeAttempts > 0 else {
                shouldBridgeBackspace = false
                return
            }

            pendingBridgeAttempts -= 1

            guard
                let activeEditor,
                activeEditor.isFirstResponder
            else {
                dispatchBridgedBackspace()
                return
            }

            shouldBridgeBackspace = false
            pendingBridgeAttempts = 0
            activeEditor.deleteBackward()
        }
    }

    private func beginDictationSession() {
        dictatedRange = selectedRange
    }

    private func updateDictationTranscript(_ transcript: String) {
        guard let dictatedRange else {
            return
        }

        let textLength = attributedText?.length ?? 0
        let clampedLocation = min(max(dictatedRange.location, 0), textLength)
        let clampedLength = min(max(dictatedRange.length, 0), max(textLength - clampedLocation, 0))
        let replacementRange = NSRange(location: clampedLocation, length: clampedLength)

        let replacementText = NSAttributedString(string: transcript, attributes: typingAttributes)
        let updatedText = NSMutableAttributedString(attributedString: attributedText ?? NSAttributedString())
        updatedText.replaceCharacters(in: replacementRange, with: replacementText)
        attributedText = updatedText

        let nextLocation = replacementRange.location + transcript.utf16.count
        self.dictatedRange = NSRange(location: replacementRange.location, length: transcript.utf16.count)
        selectedRange = NSRange(location: nextLocation, length: 0)

        delegate?.textViewDidChange?(self)
        delegate?.textViewDidChangeSelection?(self)
    }

    private func endDictationSession() {
        dictatedRange = nil
    }
}

private final class ClampedSelectionRect: UITextSelectionRect {
    private let source: UITextSelectionRect
    private let clampedRect: CGRect

    init(source: UITextSelectionRect, rect: CGRect) {
        self.source = source
        self.clampedRect = rect
    }

    override var rect: CGRect { clampedRect }
    override var writingDirection: NSWritingDirection { source.writingDirection }
    override var containsStart: Bool { source.containsStart }
    override var containsEnd: Bool { source.containsEnd }
    override var isVertical: Bool { source.isVertical }
}

extension UIFont {
    static var notyfiBody: UIFont {
        let descriptor = UIFont.systemFont(ofSize: 17, weight: .regular).fontDescriptor

        if let roundedDescriptor = descriptor.withDesign(.rounded) {
            return UIFont(descriptor: roundedDescriptor, size: 17)
        }

        return UIFont.systemFont(ofSize: 17, weight: .regular)
    }
}
