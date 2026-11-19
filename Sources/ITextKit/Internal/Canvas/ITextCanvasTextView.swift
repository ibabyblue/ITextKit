import UIKit

/// Native editor with document-owned undo commands and image-aware scroll extent.
@MainActor
final class _ITextCanvasTextView: UITextView {
    /// Prevents native text-only history from competing with complete document snapshots.
    override var undoManager: UndoManager? { nil }

    /// Document history commands and availability, supplied by the owning canvas.
    var undoAction: (() -> Void)?
    var redoAction: (() -> Void)?
    var canUndoAction: (() -> Bool)?
    var canRedoAction: (() -> Bool)?

    /// Minimum scrollable height including floating images below text.
    var minimumContentHeight: CGFloat = 0 {
        didSet { if contentSize.height != minimumContentHeight { contentSize.height = minimumContentHeight } }
    }

    /// Keeps image-only and image-tail documents scrollable after native layout.
    override func layoutSubviews() {
        super.layoutSubviews()
        if contentSize.height < minimumContentHeight { contentSize.height = minimumContentHeight }
    }

    /// Uses the document history for hardware keyboard shortcuts.
    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(input: "z", modifierFlags: .command, action: #selector(undoDocument)),
         UIKeyCommand(input: "z", modifierFlags: [.command, .shift], action: #selector(redoDocument))]
    }

    /// Enables history shortcuts only when their document operation exists.
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(undoDocument) { return canUndoAction?() ?? false }
        if action == #selector(redoDocument) { return canRedoAction?() ?? false }
        return super.canPerformAction(action, withSender: sender)
    }

    /// Executes the owner's document undo.
    @objc private func undoDocument() { undoAction?() }

    /// Executes the owner's document redo.
    @objc private func redoDocument() { redoAction?() }

    /// Keeps paste within the plain-text document contract; floating pictures use `insertImage`.
    override func paste(_ sender: Any?) {
        guard isEditable, let value = UIPasteboard.general.string else { return }
        insertText(value)
    }
}
