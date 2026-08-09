/// The caller-requested playback state of an animated text view.
public enum ITextPlaybackState: Sendable, Equatable {
    /// Advances time and renders automatic text motion.
    case playing

    /// Freezes remaining delays and in-flight animation progress.
    case paused

    /// Cancels saved progress and returns the view to its stable stopped presentation.
    case stopped
}
