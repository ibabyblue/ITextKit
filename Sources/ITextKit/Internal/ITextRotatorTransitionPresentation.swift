/// Framework-independent presentation values for one rotator transition frame.
///
/// Both renderers consume this single projection so movement and fading always start together,
/// use the same eased progress, and finish together.
struct _ITextRotatorTransitionPresentation: Equatable {
    /// Opacity and vertical offset for the item leaving through the top edge.
    let outgoing: Item

    /// Opacity and vertical offset for the item entering through the bottom edge.
    let incoming: Item

    /// Presentation values for one text layer.
    struct Item: Equatable {
        /// Visible opacity in the closed range `0...1`.
        let opacity: Double

        /// Vertical offset expressed as a multiple of this layer's own height.
        let verticalOffsetFactor: Double
    }

    /// Projects linear elapsed progress into synchronized movement and opacity values.
    ///
    /// - Parameters:
    ///   - linearProgress: Transition progress produced by the shared timing engine.
    ///   - reduceMotion: Whether movement should be removed while retaining the cross-fade.
    init(linearProgress: Double, reduceMotion: Bool) {
        let progress = _ITextEasing.easeInOut(linearProgress)
        let outgoingOpacity = 1 - progress
        outgoing = Item(
            opacity: outgoingOpacity * outgoingOpacity,
            verticalOffsetFactor: reduceMotion ? 0 : -progress
        )
        incoming = Item(
            opacity: progress * progress,
            verticalOffsetFactor: reduceMotion ? 0 : 1 - progress
        )
    }
}
