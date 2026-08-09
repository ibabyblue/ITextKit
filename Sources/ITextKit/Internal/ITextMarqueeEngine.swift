import CoreGraphics
import Foundation

/// A deterministic snapshot of marquee presentation state.
struct _ITextMarqueeSnapshot: Equatable {
    /// Travel from the semantic leading position, in points.
    let offset: CGFloat

    /// Whether the measured text exceeds the viewport width.
    let isOverflowing: Bool

    /// The caller-requested playback state.
    let playbackState: ITextPlaybackState
}

/// Advances seamless marquee timing independently from either UI framework.
@MainActor
final class _ITextMarqueeEngine {
    /// Emits presentation changes, including display-link offset updates.
    var onSnapshotChanged: ((_ITextMarqueeSnapshot) -> Void)?

    /// The effective motion values.
    private(set) var configuration: _ITextMarqueeResolvedConfiguration

    /// The caller-requested playback state.
    private(set) var playbackState: ITextPlaybackState

    /// Whether the owning view is visible in an active scene or window.
    private(set) var isEnvironmentActive = false

    /// Whether system accessibility settings allow marquee movement.
    private(set) var isMotionAllowed = true

    /// The measured untruncated text width.
    private var contentWidth: CGFloat = 0

    /// The measured clipping viewport width.
    private var viewportWidth: CGFloat = 0

    /// Travel from the semantic leading position.
    private var offset: CGFloat = 0

    /// Remaining delay before the first movement.
    private var remainingInitialDelay: TimeInterval

    /// Creates a marquee timing engine.
    ///
    /// - Parameters:
    ///   - configuration: Normalized motion configuration.
    ///   - playbackState: Initial caller-requested playback state.
    init(
        configuration: _ITextMarqueeResolvedConfiguration,
        playbackState: ITextPlaybackState
    ) {
        self.configuration = configuration
        self.playbackState = playbackState
        self.remainingInitialDelay = configuration.initialDelay
    }

    /// The current renderable state.
    var snapshot: _ITextMarqueeSnapshot {
        _ITextMarqueeSnapshot(
            offset: isMotionAllowed && playbackState != .stopped ? offset : 0,
            isOverflowing: isOverflowing,
            playbackState: playbackState
        )
    }

    /// Whether elapsed time can currently change the marquee offset.
    var shouldAdvance: Bool {
        playbackState == .playing
            && isEnvironmentActive
            && isMotionAllowed
            && isOverflowing
            && configuration.speed > 0
            && cycleDistance > 0
    }

    /// Whether the text exceeds its clipping viewport.
    private var isOverflowing: Bool {
        contentWidth > viewportWidth && viewportWidth > 0
    }

    /// Distance between equivalent positions of the repeated text copies.
    private var cycleDistance: CGFloat {
        contentWidth + configuration.spacing
    }

    /// Replaces motion values and restarts from the leading position.
    ///
    /// - Parameter newConfiguration: The latest normalized configuration.
    func updateConfiguration(_ newConfiguration: _ITextMarqueeResolvedConfiguration) {
        guard newConfiguration != configuration else { return }
        configuration = newConfiguration
        resetProgress()
        emitSnapshot()
    }

    /// Applies the latest measured text and viewport widths.
    ///
    /// Any meaningful geometry change restarts at leading and reapplies the initial delay.
    ///
    /// - Parameters:
    ///   - contentWidth: Full untruncated text width.
    ///   - viewportWidth: Visible clipping width.
    func updateMetrics(contentWidth: CGFloat, viewportWidth: CGFloat) {
        let normalizedContent = contentWidth.isFinite ? max(contentWidth, 0) : 0
        let normalizedViewport = viewportWidth.isFinite ? max(viewportWidth, 0) : 0
        guard normalizedContent != self.contentWidth
            || normalizedViewport != self.viewportWidth
        else { return }

        self.contentWidth = normalizedContent
        self.viewportWidth = normalizedViewport
        resetProgress()
        emitSnapshot()
    }

    /// Applies caller-owned playback state.
    ///
    /// Pausing preserves progress. Stopping returns to leading and discards saved progress.
    ///
    /// - Parameter newState: The requested playback state.
    func setPlaybackState(_ newState: ITextPlaybackState) {
        guard newState != playbackState else { return }
        let oldState = playbackState
        playbackState = newState
        if newState == .stopped || (newState == .playing && oldState == .stopped) {
            resetProgress()
        }
        emitSnapshot()
    }

    /// Applies window and scene visibility without changing caller-owned playback state.
    ///
    /// - Parameter isActive: Whether elapsed time is currently allowed to advance.
    func setEnvironmentActive(_ isActive: Bool) {
        isEnvironmentActive = isActive
    }

    /// Applies the current Reduce Motion permission.
    ///
    /// - Parameter isAllowed: Whether continuous movement is allowed.
    func setMotionAllowed(_ isAllowed: Bool) {
        guard isAllowed != isMotionAllowed else { return }
        isMotionAllowed = isAllowed
        emitSnapshot()
    }

    /// Restarts from the semantic leading position and reapplies the initial delay.
    func restart() {
        resetProgress()
        emitSnapshot()
    }

    /// Advances the initial delay or seamless travel by elapsed monotonic time.
    ///
    /// - Parameter elapsed: Nonnegative elapsed seconds since the previous frame.
    func advance(by elapsed: TimeInterval) {
        guard shouldAdvance, elapsed.isFinite, elapsed > 0 else { return }
        var movingTime = elapsed
        if remainingInitialDelay > 0 {
            let consumed = min(remainingInitialDelay, movingTime)
            remainingInitialDelay -= consumed
            movingTime -= consumed
        }
        guard movingTime > 0 else { return }

        let distance = CGFloat(movingTime) * configuration.speed
        offset = (offset + distance).truncatingRemainder(dividingBy: cycleDistance)
        emitSnapshot()
    }

    /// Restores leading placement and a complete initial delay.
    private func resetProgress() {
        offset = 0
        remainingInitialDelay = configuration.initialDelay
    }

    /// Emits the current state to the owning renderer.
    private func emitSnapshot() {
        onSnapshotChanged?(snapshot)
    }
}
