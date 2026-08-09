import QuartzCore

/// A display-link owner that reports monotonic frame deltas without retaining itself in a cycle.
@MainActor
final class _ITextDisplayLinkDriver {
    /// Receives elapsed seconds between display-link frames.
    var onFrame: ((CFTimeInterval) -> Void)?

    /// The currently scheduled display link.
    private var displayLink: CADisplayLink?

    /// Weak forwarding target retained by the display link.
    private lazy var proxy = _ITextDisplayLinkProxy(owner: self)

    /// Timestamp of the previous delivered frame.
    private var previousTimestamp: CFTimeInterval?

    /// Whether a display link is currently scheduled.
    var isRunning: Bool { displayLink != nil }

    /// Starts frame delivery if it is not already scheduled.
    func start() {
        guard displayLink == nil else { return }
        previousTimestamp = nil
        let link = CADisplayLink(target: proxy, selector: #selector(_ITextDisplayLinkProxy.tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    /// Stops frame delivery and discards the previous timestamp.
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        previousTimestamp = nil
    }

    /// Converts a display-link timestamp into an elapsed duration.
    ///
    /// - Parameter link: The display link delivering a frame.
    fileprivate func handle(_ link: CADisplayLink) {
        defer { previousTimestamp = link.timestamp }
        guard let previousTimestamp else { return }
        let elapsed = link.timestamp - previousTimestamp
        guard elapsed.isFinite, elapsed > 0 else { return }
        onFrame?(elapsed)
    }

    /// Invalidates frame delivery when the driver is released.
    deinit {
        displayLink?.invalidate()
    }
}

/// Weak Objective-C selector target used by ``_ITextDisplayLinkDriver``.
@MainActor
private final class _ITextDisplayLinkProxy: NSObject {
    /// The driver receiving forwarded frames.
    weak var owner: _ITextDisplayLinkDriver?

    /// Creates a forwarding target.
    ///
    /// - Parameter owner: The driver that receives frame callbacks.
    init(owner: _ITextDisplayLinkDriver) {
        self.owner = owner
    }

    /// Forwards one display-link frame.
    ///
    /// - Parameter link: The active display link.
    @objc func tick(_ link: CADisplayLink) {
        owner?.handle(link)
    }
}
