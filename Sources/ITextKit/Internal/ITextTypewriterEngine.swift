import Foundation

/// A deterministic snapshot of typewriter presentation state.
struct _ITextTypewriterSnapshot: Equatable {
    /// The number of complete extended grapheme clusters currently visible.
    let revealedCount: Int

    /// The total number of reveal units in the current content.
    let unitCount: Int

    /// Whether all current content is visible.
    var isComplete: Bool { revealedCount >= unitCount }
}

/// Advances typewriter timing independently from SwiftUI or UIKit rendering.
@MainActor
final class _ITextTypewriterEngine {
    /// Emits only when the renderable snapshot changes.
    var onSnapshotChanged: ((_ITextTypewriterSnapshot) -> Void)?

    /// The number of extended grapheme clusters in the current content.
    private(set) var unitCount: Int

    /// The effective timing values.
    private(set) var configuration: _ITextTypewriterResolvedConfiguration

    /// Whether the owning view is visible in an active scene or window.
    private(set) var isEnvironmentActive = false

    /// Whether accessibility settings allow progressive reveal.
    private(set) var isMotionAllowed = true

    /// The number of fully revealed units.
    private var revealedCount = 0

    /// Remaining delay before the first unit appears.
    private var remainingInitialDelay: TimeInterval

    /// Fractional elapsed time retained between unit reveals.
    private var elapsedSinceLastReveal: TimeInterval = 0

    /// Creates a typewriter timing engine.
    ///
    /// - Parameters:
    ///   - unitCount: Number of extended grapheme clusters in the initial content.
    ///   - configuration: Normalized reveal timing.
    init(
        unitCount: Int,
        configuration: _ITextTypewriterResolvedConfiguration
    ) {
        self.unitCount = max(unitCount, 0)
        self.configuration = configuration
        self.remainingInitialDelay = configuration.initialDelay
    }

    /// The current renderable state.
    var snapshot: _ITextTypewriterSnapshot {
        _ITextTypewriterSnapshot(
            revealedCount: min(revealedCount, unitCount),
            unitCount: unitCount
        )
    }

    /// Whether elapsed time can currently change the visible prefix.
    var shouldAdvance: Bool {
        isEnvironmentActive
            && isMotionAllowed
            && revealedCount < unitCount
    }

    /// Replaces content units and starts the new value from an empty prefix.
    ///
    /// - Parameter newUnitCount: Latest nonnegative extended-grapheme count.
    func updateUnitCount(_ newUnitCount: Int) {
        let previous = snapshot
        unitCount = max(newUnitCount, 0)
        resetProgress()
        applyImmediatePresentationIfNeeded()
        emitSnapshotIfChanged(from: previous)
    }

    /// Replaces timing and restarts current content from an empty prefix.
    ///
    /// - Parameter newConfiguration: Latest normalized timing values.
    func updateConfiguration(_ newConfiguration: _ITextTypewriterResolvedConfiguration) {
        guard newConfiguration != configuration else { return }
        let previous = snapshot
        configuration = newConfiguration
        resetProgress()
        applyImmediatePresentationIfNeeded()
        emitSnapshotIfChanged(from: previous)
    }

    /// Applies window and scene visibility without exposing public playback state.
    ///
    /// Becoming active reveals the first unit immediately when no initial delay remains.
    ///
    /// - Parameter isActive: Whether monotonic elapsed time may currently advance.
    func setEnvironmentActive(_ isActive: Bool) {
        guard isActive != isEnvironmentActive else { return }
        let previous = snapshot
        isEnvironmentActive = isActive
        applyImmediatePresentationIfNeeded()
        emitSnapshotIfChanged(from: previous)
    }

    /// Applies Reduce Motion behavior.
    ///
    /// Disallowing motion reveals the complete value. Allowing motion again never replays content.
    ///
    /// - Parameter isAllowed: Whether progressive reveal is allowed.
    func setMotionAllowed(_ isAllowed: Bool) {
        guard isAllowed != isMotionAllowed else { return }
        let previous = snapshot
        isMotionAllowed = isAllowed
        if !isAllowed {
            revealedCount = unitCount
            remainingInitialDelay = 0
            elapsedSinceLastReveal = 0
        }
        emitSnapshotIfChanged(from: previous)
    }

    /// Advances initial delay and reveal count by a monotonic elapsed duration.
    ///
    /// Long frames reveal every unit that should have appeared during the elapsed interval.
    ///
    /// - Parameter elapsed: Positive finite seconds since the previous frame.
    func advance(by elapsed: TimeInterval) {
        guard shouldAdvance, elapsed.isFinite, elapsed > 0 else { return }
        let previous = snapshot
        var unconsumed = elapsed

        if remainingInitialDelay > 0 {
            let consumed = min(remainingInitialDelay, unconsumed)
            remainingInitialDelay -= consumed
            unconsumed -= consumed
            if remainingInitialDelay == 0 {
                revealFirstUnitIfNeeded()
            }
        } else {
            revealFirstUnitIfNeeded()
        }

        if unconsumed > 0, revealedCount < unitCount {
            elapsedSinceLastReveal += unconsumed
            let remainingCount = unitCount - revealedCount
            let potentialCount = elapsedSinceLastReveal * configuration.charactersPerSecond
            if potentialCount >= TimeInterval(remainingCount) {
                revealedCount = unitCount
                elapsedSinceLastReveal = 0
            } else {
                let additionalCount = Int(potentialCount)
                if additionalCount > 0 {
                    revealedCount += additionalCount
                    elapsedSinceLastReveal -= TimeInterval(additionalCount)
                        / configuration.charactersPerSecond
                }
            }
        }

        emitSnapshotIfChanged(from: previous)
    }

    /// Restores an empty prefix and complete initial delay.
    private func resetProgress() {
        revealedCount = 0
        remainingInitialDelay = configuration.initialDelay
        elapsedSinceLastReveal = 0
    }

    /// Applies nonanimated full content or an immediate first unit when eligible.
    private func applyImmediatePresentationIfNeeded() {
        if !isMotionAllowed {
            revealedCount = unitCount
            remainingInitialDelay = 0
            elapsedSinceLastReveal = 0
        } else if isEnvironmentActive, remainingInitialDelay == 0 {
            revealFirstUnitIfNeeded()
        }
    }

    /// Reveals the first unit without applying a character interval.
    private func revealFirstUnitIfNeeded() {
        if revealedCount == 0, unitCount > 0 {
            revealedCount = 1
        }
    }

    /// Emits only when content-visible state changed.
    private func emitSnapshotIfChanged(from previous: _ITextTypewriterSnapshot) {
        let current = snapshot
        guard current != previous else { return }
        onSnapshotChanged?(current)
    }
}
