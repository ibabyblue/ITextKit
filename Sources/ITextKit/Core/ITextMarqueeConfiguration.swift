import CoreGraphics
import Foundation

/// Motion values used by seamless marquee text views.
public struct ITextMarqueeConfiguration: Sendable, Equatable {
    /// The horizontal travel speed, in points per second.
    ///
    /// Zero and negative values keep overflowing text static. Non-finite values use the default.
    public var speed: CGFloat

    /// The distance between repeated text copies, in points.
    ///
    /// Negative values resolve to zero. Non-finite values use the default.
    public var spacing: CGFloat

    /// The delay before an overflowing text begins to move, in seconds.
    ///
    /// Negative values resolve to zero. Non-finite values use the default.
    public var initialDelay: TimeInterval

    /// Creates motion configuration for a marquee text view.
    ///
    /// - Parameters:
    ///   - speed: Horizontal travel speed, in points per second.
    ///   - spacing: Distance between repeated text copies, in points.
    ///   - initialDelay: Delay before motion begins, in seconds.
    public init(
        speed: CGFloat = 30,
        spacing: CGFloat = 24,
        initialDelay: TimeInterval = 1
    ) {
        self.speed = speed
        self.spacing = spacing
        self.initialDelay = initialDelay
    }

    /// The standard 30-points-per-second seamless marquee configuration.
    public static let `default` = ITextMarqueeConfiguration()
}

extension ITextMarqueeConfiguration {
    /// The finite and nonnegative values consumed by renderers.
    var resolved: _ITextMarqueeResolvedConfiguration {
        _ITextMarqueeResolvedConfiguration(
            speed: speed.isFinite ? max(speed, 0) : 30,
            spacing: spacing.isFinite ? max(spacing, 0) : 24,
            initialDelay: initialDelay.isFinite ? max(initialDelay, 0) : 1
        )
    }
}

/// Normalized marquee motion shared by the state engine and renderers.
struct _ITextMarqueeResolvedConfiguration: Sendable, Equatable {
    /// The effective travel speed.
    let speed: CGFloat

    /// The effective gap between text copies.
    let spacing: CGFloat

    /// The effective delay before motion begins.
    let initialDelay: TimeInterval
}
