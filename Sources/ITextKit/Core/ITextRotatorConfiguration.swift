import Foundation

/// Timing values used by rotating text views.
public struct ITextRotatorConfiguration: Sendable, Equatable {
    /// The time a settled text remains visible before the next transition, in seconds.
    ///
    /// Zero and negative values disable automatic rotation. Non-finite values use the default.
    public var interval: TimeInterval

    /// The duration of the upward cross-fade, in seconds.
    ///
    /// Negative values resolve to zero. Non-finite values use the default.
    public var transitionDuration: TimeInterval

    /// Creates timing configuration for a rotating text view.
    ///
    /// - Parameters:
    ///   - interval: Time each settled text remains visible, in seconds.
    ///   - transitionDuration: Duration of one text transition, in seconds.
    public init(
        interval: TimeInterval = 3,
        transitionDuration: TimeInterval = 0.35
    ) {
        self.interval = interval
        self.transitionDuration = transitionDuration
    }

    /// The standard three-second rotation with a 0.35-second transition.
    public static let `default` = ITextRotatorConfiguration()
}

extension ITextRotatorConfiguration {
    /// The finite and nonnegative values consumed by renderers.
    var resolved: _ITextRotatorResolvedConfiguration {
        _ITextRotatorResolvedConfiguration(
            interval: interval.isFinite ? max(interval, 0) : 3,
            transitionDuration: transitionDuration.isFinite
                ? max(transitionDuration, 0)
                : 0.35
        )
    }
}

/// Normalized rotator timing shared by the state engine and renderers.
struct _ITextRotatorResolvedConfiguration: Sendable, Equatable {
    /// The effective settled-text interval.
    let interval: TimeInterval

    /// The effective transition duration.
    let transitionDuration: TimeInterval
}
