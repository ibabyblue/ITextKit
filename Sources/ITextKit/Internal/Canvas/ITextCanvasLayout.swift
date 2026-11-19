import UIKit

/// Shared geometry used for rendering, wrapping, clamping, and collision detection.
struct _ITextCanvasPlacement: Equatable {
    /// Image rectangle before rotation, in text-container coordinates.
    var frame: CGRect

    /// Clockwise radians.
    var angle: CGFloat

    /// The rotated rectangle's clockwise vertices, optionally expanded before rotation.
    func corners(clearance: CGFloat = 0) -> [CGPoint] {
        let rect = frame.insetBy(dx: -clearance, dy: -clearance)
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)].map {
            let x = $0.x - center.x
            let y = $0.y - center.y
            return CGPoint(x: center.x + cos(angle) * x - sin(angle) * y,
                           y: center.y + sin(angle) * x + cos(angle) * y)
        }
    }

    /// Axis-aligned occupied bounds, including optional local clearance.
    func bounds(clearance: CGFloat = 0) -> CGRect {
        let points = corners(clearance: clearance)
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }

    /// Exact rotated rectangle path or compatibility bounding box.
    func path(clearance: CGFloat, wrapping: ITextCanvasWrapping) -> UIBezierPath {
        if wrapping == .boundingBox { return UIBezierPath(rect: bounds().insetBy(dx: -clearance, dy: -clearance)) }
        let points = corners(clearance: clearance)
        let path = UIBezierPath()
        path.move(to: points[0])
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.close()
        return path
    }

    /// Separating-axis collision test; avoids rejecting nonintersecting rotated corners.
    func intersects(_ other: Self, clearance: CGFloat) -> Bool {
        guard bounds(clearance: clearance).intersects(other.bounds()) else { return false }
        let a = corners(clearance: clearance)
        let b = other.corners()
        for points in [a, b] {
            for index in 0..<2 {
                let edge = CGPoint(x: points[index + 1].x - points[index].x, y: points[index + 1].y - points[index].y)
                let projectionsA = a.map { -edge.y * $0.x + edge.x * $0.y }
                let projectionsB = b.map { -edge.y * $0.x + edge.x * $0.y }
                if projectionsA.max()! <= projectionsB.min()! || projectionsB.max()! <= projectionsA.min()! { return false }
            }
        }
        return true
    }

    /// Keeps the occupied bounds inside the width and above zero without changing the angle.
    func clamped(to width: CGFloat) -> Self {
        var result = self
        let occupied = result.bounds()
        if occupied.width > width {
            let scale = width / occupied.width
            let center = CGPoint(x: frame.midX, y: frame.midY)
            result.frame.size = CGSize(width: frame.width * scale, height: frame.height * scale)
            result.frame.origin = CGPoint(x: center.x - result.frame.width / 2, y: center.y - result.frame.height / 2)
        }
        let bounded = result.bounds()
        result.frame.origin.x += max(0, -bounded.minX) - max(0, bounded.maxX - width)
        result.frame.origin.y += max(0, -bounded.minY)
        return result
    }
}

/// Cached text-only layout. Floating images never feed their exclusion paths into this stack.
@MainActor
final class _ITextCanvasLayout {
    /// Text used solely for anchor positions.
    private let storage = NSTextStorage()

    /// Baseline layout manager, kept separate from visible text.
    private let manager = NSLayoutManager()

    /// Baseline container with no exclusions.
    private let container = NSTextContainer(size: .zero)

    /// Inputs of the last baseline layout.
    private var text = ""

    /// Current usable container width.
    private(set) var width: CGFloat = 1

    /// Last font and alignment used to detect measurement changes.
    private var font: UIFont?
    private var alignment: NSTextAlignment = .natural

    /// Counts actual baseline rebuilds for performance diagnostics.
    private(set) var generation = 0

    /// Creates the reusable native layout stack.
    init() {
        storage.addLayoutManager(manager)
        manager.addTextContainer(container)
        container.lineFragmentPadding = 0
    }

    /// Updates only when text or typography changes; moving an image reuses all baseline metrics.
    func prepare(text: String, width: CGFloat, font: UIFont, alignment: NSTextAlignment) {
        let width = max(1, width)
        guard self.width != width || self.font != font || self.alignment != alignment || !self.text.utf16.elementsEqual(text.utf16) else { return }
        self.text = text
        self.width = width
        self.font = font
        self.alignment = alignment
        container.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        storage.setAttributedString(NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: paragraph]))
        manager.ensureLayout(for: container)
        generation += 1
    }

    /// Returns the baseline line's top, including the empty trailing line.
    func anchorY(_ offset: Int) -> CGFloat {
        guard storage.length > 0 else { return 0 }
        let offset = Self.validOffset(offset, in: text)
        if offset == storage.length, text.hasSuffix("\n") { return manager.extraLineFragmentRect.minY }
        let glyph = manager.glyphIndexForCharacter(at: min(offset, storage.length - 1))
        return manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY
    }

    /// Resolves placements in stable order. Resizing a viewport never writes back into the document.
    func placements(_ images: [ITextCanvasImage], spacing: CGFloat, allowsOverlap: Bool) -> [_ITextCanvasPlacement] {
        var placed: [_ITextCanvasPlacement] = []
        for image in images {
            let w = width * CGFloat(Self.finite(image.widthRatio, fallback: 0.4).clamped(0.05...1))
            let aspect = CGFloat(Self.finite(image.aspectRatio, fallback: 1).clamped(0.1...10))
            let x = CGFloat(Self.finite(image.xRatio, fallback: 0.25).clamped(-1...1)) * width
            let y = anchorY(image.anchorOffset) + CGFloat(Self.finite(image.yOffset, fallback: 0).clamped(-1_000...1_000)) * width
            var pose = _ITextCanvasPlacement(frame: CGRect(x: x, y: y, width: w, height: w / aspect),
                angle: CGFloat(Self.finite(image.rotationDegrees, fallback: 0).truncatingRemainder(dividingBy: 360)) * .pi / 180).clamped(to: width)
            if !allowsOverlap {
                for _ in 0...placed.count {
                    let collisions = placed.filter { pose.intersects($0, clearance: spacing) }
                    guard let bottom = collisions.map({ $0.bounds().maxY + spacing }).max() else { break }
                    pose.frame.origin.y += bottom - pose.bounds().minY
                }
            }
            placed.append(pose)
        }
        return placed
    }

    /// Stores one accepted pose using a baseline anchor, never the wrapped text's location.
    func write(_ pose: _ITextCanvasPlacement, to image: inout ITextCanvasImage, chooseAnchor: Bool) {
        if chooseAnchor {
            let point = CGPoint(x: pose.frame.minX, y: pose.frame.minY)
            image.anchorOffset = storage.length == 0 ? 0 : Self.validOffset(manager.characterIndex(for: point, in: container, fractionOfDistanceBetweenInsertionPoints: nil), in: text)
        }
        image.xRatio = Double(pose.frame.minX / width)
        image.yOffset = Double((pose.frame.minY - anchorY(image.anchorOffset)) / width)
        image.widthRatio = Double(pose.frame.width / width)
        image.rotationDegrees = Double(pose.angle * 180 / .pi)
    }

    /// Clamps a UTF-16 offset to the start of a complete extended grapheme cluster.
    static func validOffset(_ offset: Int, in text: String) -> Int {
        let value = text as NSString
        let index = min(max(0, offset), value.length)
        return index == value.length ? index : value.rangeOfComposedCharacterSequence(at: index).location
    }

    /// Remaps anchors after a replacement, including composed input, paste, and deletions.
    static func updateAnchors(from old: String, to new: String, images: inout [ITextCanvasImage]) {
        guard !old.utf16.elementsEqual(new.utf16), !images.isEmpty else { return }
        let before = Array(old.utf16)
        let after = Array(new.utf16)
        var prefix = 0
        while prefix < min(before.count, after.count), before[prefix] == after[prefix] { prefix += 1 }
        prefix = min(validOffset(prefix, in: old), validOffset(prefix, in: new))
        var suffix = 0
        while suffix < min(before.count, after.count) - prefix, before[before.count - suffix - 1] == after[after.count - suffix - 1] { suffix += 1 }
        let oldEnd = before.count - suffix
        let newEnd = after.count - suffix
        for index in images.indices {
            let anchor = validOffset(images[index].anchorOffset, in: old)
            let shifted = anchor >= oldEnd ? anchor + newEnd - oldEnd : (anchor > prefix ? prefix : anchor)
            images[index].anchorOffset = validOffset(shifted, in: new)
        }
    }

    /// Replaces invalid floating-point values before geometric calculations.
    static func finite(_ value: Double, fallback: Double) -> Double { value.isFinite ? value : fallback }
}

private extension Double {
    /// Constrains a finite input to a closed interval.
    func clamped(_ range: ClosedRange<Double>) -> Double { min(max(self, range.lowerBound), range.upperBound) }
}
