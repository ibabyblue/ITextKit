import CoreGraphics
import Foundation

/// A semantic direction for a text highlight sweep.
///
/// The cases describe leading and trailing edges instead of physical left and
/// right edges. Renderers resolve them against the current interface direction,
/// so the same value follows right-to-left layouts automatically.
public enum ITextShimmerDirection: Sendable, Equatable, Hashable {
    /// Travels from the leading text edge to the trailing text edge.
    ///
    /// This moves left-to-right in a left-to-right interface and right-to-left
    /// in a right-to-left interface.
    case leadingToTrailing

    /// Travels from the trailing text edge to the leading text edge.
    ///
    /// This moves right-to-left in a left-to-right interface and left-to-right
    /// in a right-to-left interface.
    case trailingToLeading
}

/// Configures the timing and appearance of a text highlight sweep.
///
/// Public properties preserve exactly what the caller supplies. SwiftUI and
/// UIKit renderers resolve invalid values consistently when they consume the
/// configuration, without mutating this value, throwing an error, or logging.
public struct ITextShimmerConfiguration: Sendable, Equatable {
    /// The duration, in seconds, of one complete offscreen-to-offscreen sweep.
    ///
    /// Renderers clamp finite values to `0.2...10`. A non-finite value resolves
    /// to the default duration of `1.5` seconds.
    public var duration: TimeInterval

    /// The highlight-band width as a fraction of the rendered text width.
    ///
    /// Renderers clamp finite values to `0.05...1`. A non-finite value resolves
    /// to the default fraction of `0.28`.
    public var bandWidth: CGFloat

    /// The opacity multiplier applied to the highlight-colored text copy.
    ///
    /// Renderers clamp finite values to `0...1`. A non-finite value resolves to
    /// the default intensity of `0.85`; a resolved value of zero disables the
    /// highlight overlay while leaving the base text visible.
    public var intensity: CGFloat

    /// The semantic direction in which the highlight travels.
    ///
    /// The default is ``ITextShimmerDirection/leadingToTrailing``. Renderers
    /// resolve the value against the current left-to-right or right-to-left
    /// interface direction at presentation time.
    public var direction: ITextShimmerDirection

    /// Creates a text shimmer configuration while preserving every input.
    ///
    /// Range safety is applied only when a renderer consumes this value.
    ///
    /// - Parameters:
    ///   - duration: Sweep duration in seconds. The default is `1.5`.
    ///   - bandWidth: Band width relative to rendered text width. The default
    ///     is `0.28`.
    ///   - intensity: Highlight-copy opacity multiplier. The default is `0.85`.
    ///   - direction: Semantic travel direction. The default is
    ///     ``ITextShimmerDirection/leadingToTrailing``.
    public init(
        duration: TimeInterval = 1.5,
        bandWidth: CGFloat = 0.28,
        intensity: CGFloat = 0.85,
        direction: ITextShimmerDirection = .leadingToTrailing
    ) {
        self.duration = duration
        self.bandWidth = bandWidth
        self.intensity = intensity
        self.direction = direction
    }

    /// The standard 1.5-second, 0.28-width, 0.85-intensity,
    /// leading-to-trailing highlight sweep.
    public static let `default` = ITextShimmerConfiguration()

    /// Finite, range-safe values shared by both framework renderers.
    var resolved: ITextShimmerResolvedConfiguration {
        ITextShimmerResolvedConfiguration(
            duration: duration.isFinite
                ? min(max(duration, ITextShimmerConfigurationLimits.minimumDuration),
                      ITextShimmerConfigurationLimits.maximumDuration)
                : Self.default.duration,
            bandWidth: bandWidth.isFinite
                ? min(max(bandWidth, ITextShimmerConfigurationLimits.minimumBandWidth),
                      ITextShimmerConfigurationLimits.maximumBandWidth)
                : Self.default.bandWidth,
            intensity: intensity.isFinite
                ? min(max(intensity, ITextShimmerConfigurationLimits.minimumIntensity),
                      ITextShimmerConfigurationLimits.maximumIntensity)
                : Self.default.intensity,
            direction: direction
        )
    }
}

/// Numeric limits applied only when a renderer consumes public values.
private enum ITextShimmerConfigurationLimits {
    /// The shortest supported sweep duration, in seconds.
    static let minimumDuration: TimeInterval = 0.2

    /// The longest supported sweep duration, in seconds.
    static let maximumDuration: TimeInterval = 10

    /// The narrowest supported band relative to rendered text width.
    static let minimumBandWidth: CGFloat = 0.05

    /// The widest supported band relative to rendered text width.
    static let maximumBandWidth: CGFloat = 1

    /// The lowest supported highlight-copy opacity.
    static let minimumIntensity: CGFloat = 0

    /// The highest supported highlight-copy opacity.
    static let maximumIntensity: CGFloat = 1
}

/// Immutable values that are safe for deterministic geometry and rendering.
struct ITextShimmerResolvedConfiguration: Sendable, Equatable, Hashable {
    /// Normalized sweep duration, in seconds.
    let duration: TimeInterval

    /// Normalized band width relative to rendered text width.
    let bandWidth: CGFloat

    /// Normalized highlight-copy opacity multiplier.
    let intensity: CGFloat

    /// Caller-requested semantic travel direction.
    let direction: ITextShimmerDirection
}
