import UIKit

/// Native exclusion paths with scoped paragraph invalidation and complete-character narrow columns.
final class _ITextCanvasTextContainer: NSTextContainer, NSTextStorageDelegate {
    /// Cached widths for the canvas's uniform typography.
    private var widths: [String: CGFloat] = [:]

    /// One UTF-16 snapshot per edit; avoids bridging the whole text for every line fragment.
    private var cachedString: NSString = ""

    /// Prior image poses in stable document order.
    private var placements: [_ITextCanvasPlacement] = []

    /// Previous exclusion settings used when finding changed geometry.
    private var spacing: CGFloat = 0
    private var wrapping: ITextCanvasWrapping = .rotatedRectangle

    /// Installs native paths but invalidates only paragraphs affected by changed image geometry.
    /// Native TextKit retains ownership of bidirectional line fragments and contextual shaping.
    func updateExclusions(_ next: [_ITextCanvasPlacement], spacing: CGFloat, wrapping: ITextCanvasWrapping, incremental: Bool) {
        var affected = CGRect.null
        for index in 0..<max(placements.count, next.count) {
            let old = placements.indices.contains(index) ? placements[index] : nil
            let new = next.indices.contains(index) ? next[index] : nil
            if old != new || self.spacing != spacing || self.wrapping != wrapping {
                if let old { affected = affected.union(old.bounds(clearance: self.spacing)) }
                if let new { affected = affected.union(new.bounds(clearance: spacing)) }
            }
        }
        var range: NSRange?
        if incremental, !affected.isNull, let manager = layoutManager, let storage = manager.textStorage, storage.length > 0 {
            let glyphs = manager.glyphRange(forBoundingRect: affected.insetBy(dx: 0, dy: -128), in: self)
            let characters = manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            let start = max(0, min(storage.length - 1, characters.location) - 1)
            let end = min(storage.length, characters.location + characters.length + 1)
            range = cachedString.paragraphRange(for: NSRange(location: start, length: max(0, end - start)))
        }
        placements = next
        self.spacing = spacing
        self.wrapping = wrapping
        let manager = layoutManager as? _ITextCanvasLayoutManager
        manager?.exclusionInvalidationRange = range
        defer { manager?.exclusionInvalidationRange = nil }
        exclusionPaths = next.map { $0.path(clearance: spacing, wrapping: wrapping) }
    }

    /// Skips fragments too narrow for a complete character while preserving TextKit's RTL ordering.
    override func lineFragmentRect(forProposedRect proposedRect: CGRect, at characterIndex: Int, writingDirection baseWritingDirection: NSWritingDirection, remaining remainingRect: UnsafeMutablePointer<CGRect>?) -> CGRect {
        var remainder = CGRect.zero
        var fragment = super.lineFragmentRect(forProposedRect: proposedRect, at: characterIndex, writingDirection: baseWritingDirection, remaining: &remainder)
        defer { remainingRect?.pointee = remainder }
        // TextKit 1 can reuse a split RTL line for later paragraphs. Keep one native fragment per
        // RTL row; Arabic shaping still belongs to the typesetter and text advances vertically.
        if baseWritingDirection == .rightToLeft {
            remainder = .zero
            return fragment
        }
        guard !exclusionPaths.isEmpty, let storage = layoutManager?.textStorage, characterIndex < storage.length else { return fragment }
        let range = cachedString.rangeOfComposedCharacterSequence(at: characterIndex)
        let character = cachedString.substring(with: range)
        let width: CGFloat
        if let cached = widths[character] { width = cached }
        else { width = storage.attributedSubstring(from: range).size().width; widths[character] = width }
        while !fragment.isEmpty, fragment.width < width + 2 * lineFragmentPadding {
            guard !remainder.isEmpty else { return .zero }
            let next = remainder
            fragment = super.lineFragmentRect(forProposedRect: next, at: characterIndex, writingDirection: baseWritingDirection, remaining: &remainder)
        }
        return fragment
    }

    /// Invalidates measurements before the next layout after editing text or typography.
    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorage.EditActions, range editedRange: NSRange, changeInLength delta: Int) {
        widths.removeAll(keepingCapacity: true)
        cachedString = textStorage.string as NSString
    }
}

/// Retains unaffected paragraph layout when only floating-image exclusion geometry changes.
final class _ITextCanvasLayoutManager: NSLayoutManager {
    /// Set only around a known exclusion-path mutation. Width changes still use native invalidation.
    var exclusionInvalidationRange: NSRange?

    /// Lets native path storage update without discarding every paragraph's layout caches.
    override func textContainerChangedGeometry(_ container: NSTextContainer) {
        if let range = exclusionInvalidationRange {
            invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
        } else {
            super.textContainerChangedGeometry(container)
        }
    }
}
