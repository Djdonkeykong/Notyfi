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

    override func caretRect(for position: UITextPosition) -> CGRect {
        var rect = super.caretRect(for: position)
        let targetHeight = font?.lineHeight ?? UIFont.notyfiBody.lineHeight

        if rect.height > targetHeight * 1.2 {
            rect.size.height = targetHeight
        }

        return rect
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
