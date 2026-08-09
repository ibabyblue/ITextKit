import Foundation

/// A deterministic snapshot of rotating-text presentation state.
struct _ITextRotatorSnapshot: Equatable {
    /// The index of the last fully settled text.
    let currentIndex: Int

    /// The index entering during a transition, or `nil` while settled.
    let nextIndex: Int?

    /// Transition progress in the closed range `0...1`.
    let progress: Double

    /// The caller-requested playback state.
    let playbackState: ITextPlaybackState
}

/// Advances rotator timing independently from SwiftUI or UIKit rendering.
@MainActor
final class _ITextRotatorEngine {
    /// Emits presentation changes, including display-link progress updates.
    var onSnapshotChanged: ((_ITextRotatorSnapshot) -> Void)?

    /// Emits only after a new text finishes settling.
    var onTextSettled: ((Int, String) -> Void)?

    /// The ordered plain-text values being rotated.
    private(set) var texts: [String]

    /// The effective timing values.
    private(set) var configuration: _ITextRotatorResolvedConfiguration

    /// The caller-requested playback state.
    private(set) var playbackState: ITextPlaybackState

    /// Whether the owning view is visible in an active scene or window.
    private(set) var isEnvironmentActive = false

    /// The last fully settled item index.
    private var currentIndex = 0

    /// The item entering during a transition.
    private var nextIndex: Int?

    /// Remaining settled time before the next transition.
    private var remainingInterval: TimeInterval

    /// Elapsed time within the current transition.
    private var transitionElapsed: TimeInterval = 0

    /// Creates a rotator timing engine.
    ///
    /// - Parameters:
    ///   - texts: Ordered text values.
    ///   - configuration: Normalized timing configuration.
    ///   - playbackState: Initial caller-requested playback state.
    init(
        texts: [String],
        configuration: _ITextRotatorResolvedConfiguration,
        playbackState: ITextPlaybackState
    ) {
        self.texts = texts
        self.configuration = configuration
        self.playbackState = playbackState
        self.remainingInterval = configuration.interval
    }

    /// The current renderable state.
    var snapshot: _ITextRotatorSnapshot {
        let duration = configuration.transitionDuration
        let progress: Double
        if nextIndex != nil {
            progress = duration > 0 ? min(max(transitionElapsed / duration, 0), 1) : 1
        } else {
            progress = 0
        }
        return _ITextRotatorSnapshot(
            currentIndex: texts.isEmpty ? 0 : min(currentIndex, texts.count - 1),
            nextIndex: nextIndex,
            progress: progress,
            playbackState: playbackState
        )
    }

    /// Whether elapsed time can currently change presentation state.
    var shouldAdvance: Bool {
        playbackState == .playing
            && isEnvironmentActive
            && texts.count > 1
            && configuration.interval > 0
    }

    /// Replaces text data and resets to the first stable item when values change.
    ///
    /// - Parameter newTexts: The latest ordered text collection.
    func updateTexts(_ newTexts: [String]) {
        guard newTexts != texts else { return }
        texts = newTexts
        resetToFirstItem()
        emitSnapshot()
    }

    /// Replaces timing and restarts the current item's full settled interval.
    ///
    /// - Parameter newConfiguration: The latest normalized timing values.
    func updateConfiguration(_ newConfiguration: _ITextRotatorResolvedConfiguration) {
        guard newConfiguration != configuration else { return }
        configuration = newConfiguration
        cancelTransitionKeepingCurrentItem()
        remainingInterval = configuration.interval
        emitSnapshot()
    }

    /// Applies caller-owned playback state.
    ///
    /// Pausing preserves all progress. Stopping cancels transition progress and keeps the last
    /// fully settled text. Starting after a stop begins a complete settled interval.
    ///
    /// - Parameter newState: The requested playback state.
    func setPlaybackState(_ newState: ITextPlaybackState) {
        guard newState != playbackState else { return }
        let oldState = playbackState
        playbackState = newState
        if newState == .stopped {
            cancelTransitionKeepingCurrentItem()
            remainingInterval = configuration.interval
        } else if newState == .playing, oldState == .stopped {
            remainingInterval = configuration.interval
        }
        emitSnapshot()
    }

    /// Applies window and scene visibility without changing caller-owned playback state.
    ///
    /// - Parameter isActive: Whether elapsed time is currently allowed to advance.
    func setEnvironmentActive(_ isActive: Bool) {
        isEnvironmentActive = isActive
    }

    /// Advances waiting or transition progress by a monotonic elapsed duration.
    ///
    /// - Parameter elapsed: Nonnegative elapsed seconds since the previous frame.
    func advance(by elapsed: TimeInterval) {
        guard shouldAdvance, elapsed.isFinite, elapsed > 0 else { return }
        var unconsumed = elapsed
        var iterations = 0

        while unconsumed > 0, shouldAdvance, iterations < 1_000 {
            iterations += 1
            if nextIndex == nil {
                if remainingInterval > unconsumed {
                    remainingInterval -= unconsumed
                    unconsumed = 0
                } else {
                    unconsumed -= remainingInterval
                    remainingInterval = 0
                    beginTransition()
                    if configuration.transitionDuration == 0 {
                        settleTransition()
                    }
                }
            } else {
                let remainingTransition = max(
                    configuration.transitionDuration - transitionElapsed,
                    0
                )
                if remainingTransition > unconsumed {
                    transitionElapsed += unconsumed
                    unconsumed = 0
                    emitSnapshot()
                } else {
                    unconsumed -= remainingTransition
                    transitionElapsed = configuration.transitionDuration
                    emitSnapshot()
                    settleTransition()
                }
            }
        }
    }

    /// Begins the next cyclic transition.
    private func beginTransition() {
        guard texts.count > 1 else { return }
        nextIndex = (currentIndex + 1) % texts.count
        transitionElapsed = 0
        emitSnapshot()
    }

    /// Commits the entering text and begins its complete settled interval.
    private func settleTransition() {
        guard let nextIndex else { return }
        currentIndex = nextIndex
        self.nextIndex = nil
        transitionElapsed = 0
        remainingInterval = configuration.interval
        emitSnapshot()
        onTextSettled?(currentIndex, texts[currentIndex])
    }

    /// Cancels in-flight motion without changing the last settled item.
    private func cancelTransitionKeepingCurrentItem() {
        nextIndex = nil
        transitionElapsed = 0
    }

    /// Restores the first item and a complete settled interval.
    private func resetToFirstItem() {
        currentIndex = 0
        cancelTransitionKeepingCurrentItem()
        remainingInterval = configuration.interval
    }

    /// Emits the current state to the owning renderer.
    private func emitSnapshot() {
        onSnapshotChanged?(snapshot)
    }
}
