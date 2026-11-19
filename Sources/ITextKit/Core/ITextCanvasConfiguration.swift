import UIKit

/// Wrapping geometry for floating images. Transparent pixels do not change the exclusion shape.
public enum ITextCanvasWrapping: String, Codable, Sendable {
    /// Text follows the rotated rectangular edge, with the configured clearance.
    case rotatedRectangle
    /// Text avoids the horizontal bounding box, retaining more whitespace at rotated corners.
    case boundingBox
}

/// Appearance and interaction settings shared by UIKit and SwiftUI canvases.
public struct ITextCanvasConfiguration: Equatable {
    /// Uniform body font. Use a preferred font with `adjustsFontForContentSizeCategory` for scaling.
    public var font: UIFont = .preferredFont(forTextStyle: .body)

    /// Body text color, resolved with the view's traits.
    public var textColor: UIColor = .label

    /// Text alignment, including natural alignment for bidirectional text.
    public var textAlignment: NSTextAlignment = .natural

    /// Whether preferred fonts follow the content-size category.
    public var adjustsFontForContentSizeCategory = true

    /// Padding between the viewport and the text container, in points.
    public var contentInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

    /// Minimum clearance around the image in points. Invalid values resolve to 6; range 0...64.
    public var imageSpacing: CGFloat = 6

    /// The exclusion shape. Defaults to following rotated edges.
    public var wrapping: ITextCanvasWrapping = .rotatedRectangle

    /// Long-press delay before one-finger movement, in seconds; clamped to 0.15...1.
    public var longPressDuration: TimeInterval = 0.35

    /// When false, manipulation rejects poses intersecting another image's clearance region.
    public var allowsImageOverlap = false

    /// Creates the default configuration. Customize properties before assigning to the canvas.
    public init() {}
}
