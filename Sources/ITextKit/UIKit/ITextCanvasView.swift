import UIKit

/// An editable native text canvas with draggable, rotatable floating images and live wrapping.
///
/// Set a bounded frame for internal scrolling (the default), or disable scrolling and constrain
/// the width to use intrinsic content height in an outer scroll view. Image providers must return
/// already-loaded images quickly; call `reloadImages()` after asynchronous loading finishes.
@MainActor
public final class ITextCanvasView: UIView {
    /// Persistent content. Equal assignments preserve selection, composition, and active gestures.
    /// An external replacement clears document undo history. Replacements during marked input are
    /// deferred until composition finishes; the most recent external replacement wins.
    public var document: ITextCanvasDocument {
        get { storedDocument }
        set { replaceDocument(newValue) }
    }

    /// Enables text editing and image manipulation. Read-only mode still permits text selection.
    public var isEditable = true {
        didSet {
            guard isEditable != oldValue else { return }
            endManipulation(cancelled: true)
            textView.isEditable = isEditable
            if !isEditable { textView.resignFirstResponder() }
            updateImageAccessibility()
        }
    }

    /// Enables internal scrolling. Disable when a parent owns scrolling and uses intrinsic height.
    public var isScrollEnabled = true {
        didSet { textView.isScrollEnabled = isScrollEnabled; invalidateIntrinsicContentSize() }
    }

    /// Typography, exclusion geometry, and gesture settings.
    public var configuration = ITextCanvasConfiguration() {
        didSet {
            guard configuration != oldValue else { return }
            endManipulation(cancelled: true)
            applyStyle()
            geometryDirty = true
            setNeedsLayout()
        }
    }

    /// Supplies decoded image content by resource key. Nil keeps a stable placeholder rectangle.
    /// This closure is called on insertion or `reloadImages()`, never for individual gesture frames.
    public var imageProvider: ((String) -> UIImage?)? {
        didSet { reloadImages() }
    }

    /// Called after committed text edits or image operations; a gesture produces one notification.
    public var onDocumentChange: ((ITextCanvasDocument) -> Void)?

    /// Called when manipulation acquires/releases interaction ownership, including cancellation.
    /// Outer scroll containers can suspend competing gestures for this interval.
    public var onInteractionChange: ((Bool) -> Void)?

    /// Called when an image is tapped, in either editing or read-only mode.
    public var onImageTap: ((UUID) -> Void)?

    /// Called after the measured content height changes. Coordinates include content insets.
    public var onContentHeightChange: ((CGFloat) -> Void)?

    /// Current measured content height, including images and an empty trailing text line.
    public private(set) var contentHeight: CGFloat = 0

    /// Whether the document history can undo an edit. Marked input must finish before undoing.
    public var canUndo: Bool { history.canUndo && textView.markedTextRange == nil }

    /// Whether the document history can redo an edit.
    public var canRedo: Bool { history.canRedo && textView.markedTextRange == nil }

    /// Document-level undo manager shared by image and text operations.
    public override var undoManager: UndoManager? { history }

    /// Native editor, internal so package tests exercise actual selection and input behavior.
    let textView: _ITextCanvasTextView

    /// Text-only anchor layout; reused throughout a manipulation.
    let baseline = _ITextCanvasLayout()

    /// Number of actual exclusion updates, for performance regression tests.
    private(set) var exclusionGeneration = 0

    /// Resolved geometry for current content. Viewport normalization never mutates stored values.
    private(set) var placements: [_ITextCanvasPlacement] = []

    /// Stable image views, keyed by placement rather than resource identity.
    private var imageViews: [UUID: UIImageView] = [:]

    /// Current serialized state; temporary gesture poses live in `manipulation`.
    private var storedDocument = ITextCanvasDocument()

    /// Most recently published complete input transaction.
    private var committedDocument = ITextCanvasDocument()

    /// Last external replacement received during input-method composition.
    private var deferredDocument: ITextCanvasDocument?

    /// Undo entries store document values, not image bytes. Typing events are individual operations.
    private let history = UndoManager()

    /// Guards delegate callbacks when restoring or replacing text programmatically.
    private var applying = false

    /// Indicates that base placements must be recomputed.
    private var geometryDirty = true

    /// Last laid-out usable width and exclusion geometry.
    private var previousWidth: CGFloat = 0
    private var previousExclusions: [_ITextCanvasPlacement] = []
    private var previousSpacing: CGFloat = -1
    private var previousWrapping: ITextCanvasWrapping = .rotatedRectangle

    /// Current manipulation transaction, shared by drag and rotation recognizers.
    private struct Manipulation {
        var id: UUID
        var original: _ITextCanvasPlacement
        var accepted: _ITextCanvasPlacement
        var translation = CGPoint.zero
        var rotation: CGFloat = 0
        var dragLocation: CGPoint?
        var touchCount = 0
        var dragging = false
        var rotating = false
    }

    /// Nil outside a user manipulation.
    private var manipulation: Manipulation?

    /// Native scroll views temporarily suspended during an image gesture, with original state.
    private var suspendedScrollViews: [(UIScrollView, Bool)] = []

    /// Creates a canvas with empty content and internal scrolling.
    /// - Parameter frame: Initial viewport rectangle.
    public override init(frame: CGRect) {
        let storage = NSTextStorage()
        let manager = _ITextCanvasLayoutManager()
        let container = _ITextCanvasTextContainer(size: .zero)
        storage.addLayoutManager(manager)
        manager.addTextContainer(container)
        storage.delegate = container
        textView = _ITextCanvasTextView(frame: .zero, textContainer: container)
        super.init(frame: frame)
        setup()
    }

    /// Storyboard initialization is unsupported; create a canvas programmatically.
    public required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    /// A finite default height for scrolling; full content height for an externally scrolled canvas.
    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: isScrollEnabled ? 320 : max(1, contentHeight))
    }

    /// Releases gesture ownership if the canvas leaves its window.
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { endManipulation(cancelled: true) }
    }

    /// Remeasures preferred fonts when Dynamic Type changes.
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            applyStyle()
            geometryDirty = true
            setNeedsLayout()
        }
    }

    /// Resolves all pending geometry at most once per normal UIKit layout pass.
    public override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds
        let inset = textView.textContainerInset
        let width = max(1, bounds.width - inset.left - inset.right)
        guard bounds.width > inset.left + inset.right else { return }
        if previousWidth != width {
            endManipulation(cancelled: true)
            previousWidth = width
            geometryDirty = true
        }
        if geometryDirty {
            baseline.prepare(text: storedDocument.text, width: width, font: effectiveFont, alignment: configuration.textAlignment)
            placements = baseline.placements(storedDocument.images, spacing: spacing, allowsOverlap: configuration.allowsImageOverlap)
            geometryDirty = false
        }
        var rendered = placements
        if let active = manipulation, let index = storedDocument.images.firstIndex(where: { $0.id == active.id }), rendered.indices.contains(index) {
            rendered[index] = active.accepted
        }
        if rendered != previousExclusions || spacing != previousSpacing || configuration.wrapping != previousWrapping {
            (textView.textContainer as? _ITextCanvasTextContainer)?.updateExclusions(rendered, spacing: spacing, wrapping: configuration.wrapping, incremental: manipulation != nil)
            previousExclusions = rendered
            previousSpacing = spacing
            previousWrapping = configuration.wrapping
            exclusionGeneration += 1
        }
        for (index, item) in storedDocument.images.enumerated() where rendered.indices.contains(index) {
            guard let view = imageViews[item.id] else { continue }
            let pose = rendered[index]
            view.bounds = CGRect(origin: .zero, size: pose.frame.size)
            view.center = CGPoint(x: pose.frame.midX + inset.left, y: pose.frame.midY + inset.top)
            view.transform = CGAffineTransform(rotationAngle: pose.angle)
            view.layer.borderWidth = manipulation?.id == item.id ? 2 : 0
            view.accessibilityValue = "\(Int(pose.angle * 180 / .pi))°"
        }
        let container = textView.textContainer
        if container.size.width != width { container.size = CGSize(width: width, height: .greatestFiniteMagnitude) }
        let manager = textView.layoutManager
        manager.ensureLayout(for: container)
        let trailing = manager.extraLineFragmentTextContainer === container ? manager.extraLineFragmentRect.maxY : 0
        let textBottom = max(manager.usedRect(for: container).maxY, trailing)
        let imageBottom = rendered.map { $0.bounds().maxY + spacing }.max() ?? 0
        let height = ceil(max(effectiveFont.lineHeight, textBottom, imageBottom) + inset.top + inset.bottom)
        textView.minimumContentHeight = height
        if abs(contentHeight - height) > 0.5 {
            contentHeight = height
            invalidateIntrinsicContentSize()
            onContentHeightChange?(height)
        }
    }

    /// Refreshes decoded images without changing geometry, selection, or input composition.
    public func reloadImages() {
        for item in storedDocument.images { imageViews[item.id]?.image = imageProvider?(item.resourceKey) }
    }

    /// Inserts an image using its normalized geometry. Duplicate IDs and read-only inserts fail.
    /// - Parameter image: Image placement with a unique identity.
    /// - Returns: Whether the placement was inserted.
    @discardableResult
    public func insertImage(_ image: ITextCanvasImage) -> Bool {
        guard isEditable, textView.markedTextRange == nil, !storedDocument.images.contains(where: { $0.id == image.id }) else { return false }
        endManipulation(cancelled: true)
        let before = storedDocument
        storedDocument.images.append(image)
        synchronizeImages()
        geometryDirty = true
        setNeedsLayout()
        commit(from: before, name: "Insert Image")
        return true
    }

    /// Removes one placement and preserves unrelated resources.
    /// - Parameter id: Placement identity to remove.
    public func removeImage(id: UUID) {
        guard isEditable, textView.markedTextRange == nil, storedDocument.images.contains(where: { $0.id == id }) else { return }
        endManipulation(cancelled: true)
        let before = storedDocument
        storedDocument.images.removeAll { $0.id == id }
        synchronizeImages()
        geometryDirty = true
        setNeedsLayout()
        commit(from: before, name: "Remove Image")
    }

    /// Applies an accessible/programmatic rotation as one undoable operation, with the same
    /// collision and bounds rules as touch interaction.
    /// - Parameters:
    ///   - id: Placement to rotate.
    ///   - degrees: Absolute clockwise angle. Nonfinite input is ignored.
    public func rotateImage(id: UUID, to degrees: Double) {
        guard degrees.isFinite else { return }
        beginManipulation(id: id)
        guard let active = manipulation, active.id == id else { return }
        updateManipulation(translation: .zero, rotation: CGFloat(degrees) * .pi / 180 - active.original.angle)
        endManipulation(cancelled: false)
    }

    /// Undoes one committed text edit, composition, insertion, removal, or complete gesture.
    public func undo() {
        guard isEditable, canUndo else { return }
        endManipulation(cancelled: true)
        history.undo()
    }

    /// Reapplies the most recently undone document operation.
    public func redo() {
        guard isEditable, canRedo else { return }
        endManipulation(cancelled: true)
        history.redo()
    }

    /// Ends keyboard input while preserving content and selection.
    public func finishEditing() { textView.resignFirstResponder() }

    /// Returns the rotated image bounds in this view's viewport coordinates.
    /// - Parameter id: Placement identity.
    /// - Returns: Visible-coordinate bounds, or nil if the ID is absent.
    public func imageRect(id: UUID) -> CGRect? {
        layoutIfNeeded()
        guard let view = imageViews[id] else { return nil }
        return view.convert(view.bounds, to: self)
    }
}

// MARK: - State and layout
extension ITextCanvasView {
    /// Resolved body font without double-scaling a preferred font.
    private var effectiveFont: UIFont {
        guard configuration.adjustsFontForContentSizeCategory,
              let style = configuration.font.fontDescriptor.object(forKey: .textStyle) as? String else { return configuration.font }
        return .preferredFont(forTextStyle: UIFont.TextStyle(rawValue: style), compatibleWith: traitCollection)
    }

    /// Sanitized gap for wrapping and collisions.
    private var spacing: CGFloat { configuration.imageSpacing.isFinite ? min(max(configuration.imageSpacing, 0), 64) : 6 }

    /// Creates the native editor and document keyboard commands.
    private func setup() {
        history.groupsByEvent = false
        history.levelsOfUndo = 100
        textView.backgroundColor = .clear
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = self
        textView.keyboardDismissMode = .interactive
        textView.accessibilityIdentifier = "ITextCanvas.text"
        textView.undoAction = { [weak self] in self?.undo() }
        textView.redoAction = { [weak self] in self?.redo() }
        textView.canUndoAction = { [weak self] in self?.canUndo ?? false }
        textView.canRedoAction = { [weak self] in self?.canRedo ?? false }
        addSubview(textView)
        applyStyle()
        NotificationCenter.default.addObserver(self, selector: #selector(deactivated), name: UIApplication.willResignActiveNotification, object: nil)
    }

    /// Cancels outstanding gestures before the application stops accepting input.
    @objc private func deactivated() { endManipulation(cancelled: true) }

    /// Updates native text styling without replacing its string or marked range.
    private func applyStyle() {
        textView.font = effectiveFont
        textView.textColor = configuration.textColor
        textView.textAlignment = configuration.textAlignment
        let value = configuration.contentInset
        func edge(_ value: CGFloat) -> CGFloat { value.isFinite ? max(0, min(value, 256)) : 12 }
        textView.textContainerInset = UIEdgeInsets(top: edge(value.top), left: edge(value.left), bottom: edge(value.bottom), right: edge(value.right))
        for view in imageViews.values {
            for case let gesture as UILongPressGestureRecognizer in view.gestureRecognizers ?? [] {
                gesture.minimumPressDuration = configuration.longPressDuration.isFinite ? min(max(configuration.longPressDuration, 0.15), 1) : 0.35
            }
        }
    }

    /// Removes duplicate placement IDs while preserving stable order.
    private func normalized(_ value: ITextCanvasDocument) -> ITextCanvasDocument {
        var value = value
        var ids = Set<UUID>()
        value.images = value.images.filter { ids.insert($0.id).inserted }
        return value
    }

    /// Replaces external content only when changed; composition and equal SwiftUI echoes are safe.
    private func replaceDocument(_ value: ITextCanvasDocument) {
        let value = normalized(value)
        guard value != storedDocument else { return }
        if textView.markedTextRange != nil {
            if value != committedDocument { deferredDocument = value }
            return
        }
        endManipulation(cancelled: true)
        apply(value)
        committedDocument = value
        history.removeAllActions()
    }

    /// Applies a snapshot, preserving the current selection when only image geometry changes.
    private func apply(_ value: ITextCanvasDocument) {
        applying = true
        defer { applying = false }
        storedDocument = value
        if !textView.text.utf16.elementsEqual(value.text.utf16) {
            let selected = textView.selectedRange
            textView.text = value.text
            let start = _ITextCanvasLayout.validOffset(selected.location, in: value.text)
            let end = _ITextCanvasLayout.validOffset(min(value.text.utf16.count, selected.location + selected.length), in: value.text)
            textView.selectedRange = NSRange(location: start, length: max(0, end - start))
            applyStyle()
        }
        synchronizeImages()
        geometryDirty = true
        setNeedsLayout()
    }

    /// Records an atomic document operation. Redo is registered while restoring its inverse.
    private func commit(from before: ITextCanvasDocument, name: String) {
        guard before != storedDocument else { return }
        history.beginUndoGrouping()
        history.registerUndo(withTarget: self) { target in target.restore(before, name: name) }
        history.setActionName(name)
        history.endUndoGrouping()
        committedDocument = storedDocument
        onDocumentChange?(storedDocument)
    }

    /// Restores a history snapshot and records the opposite direction for undo/redo.
    private func restore(_ value: ITextCanvasDocument, name: String) {
        let before = storedDocument
        apply(value)
        history.registerUndo(withTarget: self) { target in target.restore(before, name: name) }
        history.setActionName(name)
        committedDocument = storedDocument
        onDocumentChange?(storedDocument)
    }

    /// Reuses image views and decoded content; resource resolution never occurs during movement.
    private func synchronizeImages() {
        let ids = Set(storedDocument.images.map(\.id))
        for id in Array(imageViews.keys) where !ids.contains(id) { imageViews.removeValue(forKey: id)?.removeFromSuperview() }
        for item in storedDocument.images {
            let view: UIImageView
            if let existing = imageViews[item.id] { view = existing }
            else {
                view = UIImageView()
                view.backgroundColor = .secondarySystemFill
                view.contentMode = .scaleAspectFit
                view.isUserInteractionEnabled = true
                view.isAccessibilityElement = true
                view.layer.borderColor = tintColor.cgColor
                let drag = UILongPressGestureRecognizer(target: self, action: #selector(dragged(_:)))
                drag.delegate = self
                let rotation = UIRotationGestureRecognizer(target: self, action: #selector(rotated(_:)))
                rotation.delegate = self
                let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
                tap.require(toFail: drag)
                tap.require(toFail: rotation)
                view.addGestureRecognizer(drag)
                view.addGestureRecognizer(rotation)
                view.addGestureRecognizer(tap)
                textView.addSubview(view)
                imageViews[item.id] = view
            }
            if view.accessibilityIdentifier != "ITextCanvas.image.\(item.id.uuidString)" || view.layer.name != item.resourceKey {
                view.image = imageProvider?(item.resourceKey)
                view.layer.name = item.resourceKey
            }
            view.accessibilityIdentifier = "ITextCanvas.image.\(item.id.uuidString)"
            view.accessibilityLabel = item.accessibilityLabel
            textView.bringSubviewToFront(view)
        }
        applyStyle()
        updateImageAccessibility()
    }

    /// Exposes non-touch alternatives for rotation and deletion.
    private func updateImageAccessibility() {
        for item in storedDocument.images {
            imageViews[item.id]?.accessibilityTraits = [.image, .button]
            imageViews[item.id]?.accessibilityCustomActions = isEditable ? [
                UIAccessibilityCustomAction(name: "Rotate clockwise") { [weak self] _ in
                    guard let self, let current = self.storedDocument.images.first(where: { $0.id == item.id }) else { return false }
                    self.rotateImage(id: item.id, to: current.rotationDegrees + 15)
                    return true
                },
                UIAccessibilityCustomAction(name: "Rotate counterclockwise") { [weak self] _ in
                    guard let self, let current = self.storedDocument.images.first(where: { $0.id == item.id }) else { return false }
                    self.rotateImage(id: item.id, to: current.rotationDegrees - 15)
                    return true
                },
                UIAccessibilityCustomAction(name: "Remove image") { [weak self] _ in self?.removeImage(id: item.id); return true }
            ] : nil
        }
    }
}

// MARK: - Manipulation transaction
extension ITextCanvasView {
    /// Begins one transaction; the same path is used by gestures and accessible rotation.
    func beginManipulation(id: UUID) {
        guard isEditable, manipulation == nil, textView.markedTextRange == nil else { return }
        layoutIfNeeded()
        guard let index = storedDocument.images.firstIndex(where: { $0.id == id }), placements.indices.contains(index) else { return }
        textView.resignFirstResponder()
        let pose = placements[index]
        manipulation = Manipulation(id: id, original: pose, accepted: pose)
        var ancestor: UIView? = textView
        while let current = ancestor {
            if let scroll = current as? UIScrollView {
                suspendedScrollViews.append((scroll, scroll.isScrollEnabled))
                scroll.isScrollEnabled = false
            }
            ancestor = current.superview
        }
        onInteractionChange?(true)
        setNeedsLayout()
    }

    /// Proposes an absolute gesture delta from the starting pose; rejected poses never move peers.
    func updateManipulation(translation: CGPoint, rotation: CGFloat) {
        guard var active = manipulation, translation.x.isFinite, translation.y.isFinite, rotation.isFinite else { return }
        var pose = active.original
        pose.frame.origin.x += translation.x
        pose.frame.origin.y += translation.y
        pose.angle = (pose.angle + rotation).truncatingRemainder(dividingBy: 2 * .pi)
        pose = pose.clamped(to: baseline.width)
        if !configuration.allowsImageOverlap {
            for (index, item) in storedDocument.images.enumerated() where item.id != active.id && placements.indices.contains(index) {
                if pose.intersects(placements[index], clearance: spacing) { return }
            }
        }
        active.accepted = pose
        manipulation = active
        setNeedsLayout()
    }

    /// Commits once or restores on cancellation, and unconditionally releases suspended scrolling.
    func endManipulation(cancelled: Bool) {
        guard let active = manipulation else { return }
        manipulation = nil
        for (scroll, enabled) in suspendedScrollViews { scroll.isScrollEnabled = enabled }
        suspendedScrollViews.removeAll()
        if !cancelled, active.accepted != active.original,
           let index = storedDocument.images.firstIndex(where: { $0.id == active.id }) {
            let before = storedDocument
            baseline.write(active.accepted, to: &storedDocument.images[index], chooseAnchor: true)
            geometryDirty = true
            commit(from: before, name: "Transform Image")
        }
        onInteractionChange?(false)
        setNeedsLayout()
    }

    /// Finds the identity attached to a recognizer's image view.
    private func imageID(for gesture: UIGestureRecognizer) -> UUID? { imageViews.first(where: { $0.value === gesture.view })?.key }

    /// Tracks translation in window coordinates, rebasing when a finger is added or removed.
    @objc private func dragged(_ gesture: UILongPressGestureRecognizer) {
        guard let id = imageID(for: gesture) else { return }
        if gesture.state == .began { beginManipulation(id: id) }
        guard var active = manipulation, active.id == id else { return }
        let point = gesture.location(in: window)
        switch gesture.state {
        case .began, .changed:
            if active.touchCount == gesture.numberOfTouches, let last = active.dragLocation {
                active.translation.x += point.x - last.x
                active.translation.y += point.y - last.y
            }
            active.dragLocation = point
            active.touchCount = gesture.numberOfTouches
            active.dragging = true
            manipulation = active
            updateManipulation(translation: active.translation, rotation: active.rotation)
        case .ended:
            active.dragging = false
            manipulation = active
            if !active.rotating { endManipulation(cancelled: false) }
        case .cancelled, .failed: endManipulation(cancelled: true)
        default: break
        }
    }

    /// Adds continuous two-finger rotation to the same transaction as long-press movement.
    @objc private func rotated(_ gesture: UIRotationGestureRecognizer) {
        guard let id = imageID(for: gesture) else { return }
        if gesture.state == .began { beginManipulation(id: id) }
        guard var active = manipulation, active.id == id else { return }
        switch gesture.state {
        case .began, .changed:
            active.rotating = true
            active.rotation += gesture.rotation
            gesture.rotation = 0
            manipulation = active
            updateManipulation(translation: active.translation, rotation: active.rotation)
        case .ended:
            active.rotating = false
            manipulation = active
            if !active.dragging { endManipulation(cancelled: false) }
        case .cancelled, .failed: endManipulation(cancelled: true)
        default: break
        }
    }

    /// Forwards image activation without imposing a viewer or picker.
    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        if let id = imageID(for: gesture) { onImageTap?(id) }
    }
}

extension ITextCanvasView: UITextViewDelegate, UIGestureRecognizerDelegate {
    /// Coalesces marked input into one document-history entry; never rewrites marked text.
    public func textViewDidChange(_ textView: UITextView) {
        guard !applying else { return }
        _ITextCanvasLayout.updateAnchors(from: storedDocument.text, to: textView.text, images: &storedDocument.images)
        storedDocument.text = textView.text
        geometryDirty = true
        setNeedsLayout()
        if textView.markedTextRange == nil {
            if let deferred = deferredDocument {
                deferredDocument = nil
                replaceDocument(deferred)
            } else { commit(from: committedDocument, name: "Edit Text") }
        }
    }

    /// Publishes composition committed by resigning first responder.
    public func textViewDidEndEditing(_ textView: UITextView) { textViewDidChange(textView) }

    /// Rejects image manipulation in read-only mode and while composing text.
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        isEditable && textView.markedTextRange == nil && (manipulation == nil || manipulation?.id == imageID(for: gestureRecognizer))
    }

    /// Only a drag and rotation belonging to the same image may share recognition.
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer.view === otherGestureRecognizer.view &&
        ((gestureRecognizer is UILongPressGestureRecognizer && otherGestureRecognizer is UIRotationGestureRecognizer) ||
         (gestureRecognizer is UIRotationGestureRecognizer && otherGestureRecognizer is UILongPressGestureRecognizer))
    }
}
