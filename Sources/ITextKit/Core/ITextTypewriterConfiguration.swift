import Foundation

/// Timing values used by typewriter text views.
public struct ITextTypewriterConfiguration: Sendable, Equatable {
    /// The number of extended grapheme clusters revealed per second.
    ///
    /// Nonpositive and non-finite values resolve to the default value.
    public var charactersPerSecond: Double

    /// The delay before the first character appears, in seconds.
    ///
    /// Negative values resolve to zero. Non-finite values use the default.
    public var initialDelay: TimeInterval

    /// Creates timing configuration for a typewriter text view.
    ///
    /// - Parameters:
    ///   - charactersPerSecond: Extended grapheme clusters revealed per second.
    ///   - initialDelay: Delay before the first character appears, in seconds.
    public init(
        charactersPerSecond: Double = 20,
        initialDelay: TimeInterval = 0
    ) {
        self.charactersPerSecond = charactersPerSecond
        self.initialDelay = initialDelay
    }

    /// The standard 20-characters-per-second configuration with no initial delay.
    public static let `default` = ITextTypewriterConfiguration()
}

extension ITextTypewriterConfiguration {
    /// The finite values consumed by the deterministic timing engine.
    var resolved: _ITextTypewriterResolvedConfiguration {
        _ITextTypewriterResolvedConfiguration(
            charactersPerSecond: charactersPerSecond.isFinite && charactersPerSecond > 0
                ? charactersPerSecond
                : 20,
            initialDelay: initialDelay.isFinite ? max(initialDelay, 0) : 0
        )
    }
}

/// Normalized typewriter timing shared by framework adapters.
struct _ITextTypewriterResolvedConfiguration: Sendable, Equatable {
    /// The effective extended-grapheme reveal speed.
    let charactersPerSecond: Double

    /// The effective delay before the first character.
    let initialDelay: TimeInterval
}
