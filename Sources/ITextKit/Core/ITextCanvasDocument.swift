import Foundation

/// Plain editable text and independently positioned images. Image bytes are supplied separately.
///
/// Encode this value to save a document. Layout coordinates are relative to the text container's
/// usable width, not the screen. Font metrics still determine line wrapping on each device.
public struct ITextCanvasDocument: Codable, Equatable, Sendable {
    /// Complete text, including newlines. Anchors count UTF-16 code units.
    public var text: String

    /// Images in stable back-to-front order. Each placement must have a unique ID.
    public var images: [ITextCanvasImage]

    /// Creates a document.
    /// - Parameters:
    ///   - text: Complete plain text.
    ///   - images: Ordered floating image placements; duplicate IDs are ignored after the first.
    public init(text: String = "", images: [ITextCanvasImage] = []) {
        self.text = text
        self.images = images
    }

    /// Compares the exact UTF-16 representation because canonically equivalent strings can have
    /// different anchor offsets.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.text.utf16.elementsEqual(rhs.text.utf16) && lhs.images == rhs.images
    }
}

/// A floating image's persistent identity and geometry; loading and uploading remain caller-owned.
public struct ITextCanvasImage: Codable, Equatable, Identifiable, Sendable {
    /// Identity of this placement. Repeated uses of one resource have different IDs.
    public var id: UUID

    /// Opaque resource identifier interpreted by the caller.
    public var resourceKey: String

    /// Accessible description of the image, independent of its resource identifier.
    public var accessibilityLabel: String

    /// UTF-16 offset into text before exclusion paths are applied; clamped to a character boundary.
    public var anchorOffset: Int

    /// Unrotated left edge divided by usable text width. Positive x points physically right.
    public var xRatio: Double

    /// Unrotated top edge relative to the anchor line, divided by usable text width.
    public var yOffset: Double

    /// Unrotated width divided by usable text width; rendering clamps to 0.05...1.
    public var widthRatio: Double

    /// Unrotated width divided by height; rendering clamps to 0.1...10.
    public var aspectRatio: Double

    /// Clockwise degrees about the image center; rendering normalizes modulo 360.
    public var rotationDegrees: Double

    /// Creates a floating image placement. Geometry is available before image decoding completes.
    /// - Parameters:
    ///   - id: Stable placement identity, distinct from the resource key.
    ///   - resourceKey: Caller-owned resource identifier.
    ///   - accessibilityLabel: Description spoken by VoiceOver.
    ///   - anchorOffset: UTF-16 offset into the baseline text.
    ///   - xRatio: Relative unrotated left edge.
    ///   - yOffset: Relative vertical offset from the baseline anchor line.
    ///   - widthRatio: Relative unrotated width.
    ///   - aspectRatio: Width divided by height, independent of decoded image size.
    ///   - rotationDegrees: Clockwise rotation in degrees.
    public init(
        id: UUID = UUID(), resourceKey: String, accessibilityLabel: String = "Image",
        anchorOffset: Int = 0, xRatio: Double = 0.25, yOffset: Double = 0,
        widthRatio: Double = 0.4, aspectRatio: Double = 1, rotationDegrees: Double = 0
    ) {
        self.id = id
        self.resourceKey = resourceKey
        self.accessibilityLabel = accessibilityLabel
        self.anchorOffset = anchorOffset
        self.xRatio = xRatio
        self.yOffset = yOffset
        self.widthRatio = widthRatio
        self.aspectRatio = aspectRatio
        self.rotationDegrees = rotationDegrees
    }
}
