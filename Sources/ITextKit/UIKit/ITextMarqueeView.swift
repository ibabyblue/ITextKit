import UIKit

/// A UIKit view that moves one overflowing line of plain or attributed text in a seamless loop.
///
/// Two private labels provide continuous repetition without becoming duplicate accessibility
/// elements. Text that fits, stopped playback, zero speed, and Reduce Motion all use one static,
/// tail-truncated label.
@MainActor
public final class ITextMarqueeView: UIView {
    /// The already-localized plain text displayed by the view.
    ///
    /// Setting this property replaces rich content and discards its attributes. Reading it returns
    /// the plain characters of the current rich content.
    public var text: String {
        get { storedAttributedText.string }
        set { replaceAttributedText(NSAttributedString(string: newValue)) }
    }

    /// The already-localized attributed text displayed by the view.
    ///
    /// Assignment takes an immutable snapshot. Any content or attribute change returns motion to
    /// semantic leading and remeasures without changing explicit playback state.
    public var attributedText: NSAttributedString {
        get { NSAttributedString(attributedString: storedAttributedText) }
        set { replaceAttributedText(newValue) }
    }

    /// Shared marquee speed, copy spacing, and initial delay.
    public var configuration: ITextMarqueeConfiguration = .default {
        didSet {
            guard configuration != oldValue else { return }
            engine.updateConfiguration(configuration.resolved)
            applySnapshot(engine.snapshot)
            reconcileDisplayLink()
            setNeedsLayout()
        }
    }

    /// Shared fill and outline applied to both seamless text copies.
    public var textStyle: ITextUIKitStyle? {
        didSet {
            guard textStyle != oldValue else { return }
            let oldWidth = resolvedStrokeWidth(oldValue)
            let newWidth = resolvedStrokeWidth(textStyle)
            for label in [primaryLabel, repeatedLabel] {
                label.textStyle = textStyle
            }
            invalidateIntrinsicContentSize()
            if oldWidth != newWidth {
                engine.restart()
                applySnapshot(engine.snapshot)
            }
            setNeedsLayout()
        }
    }

    /// The font applied to both private labels.
    public var font: UIFont = .preferredFont(forTextStyle: .body) {
        didSet { synchronizeLabelStyle(restartMotion: true) }
    }

    /// The dynamic text color applied to both private labels.
    public var textColor: UIColor = .label {
        didSet { synchronizeLabelStyle(restartMotion: false) }
    }

    /// Alignment used by static text that does not need marquee movement.
    public var textAlignment: NSTextAlignment = .natural {
        didSet { synchronizeLabelStyle(restartMotion: false) }
    }

    /// Whether preferred text styles update with the content-size category.
    public var adjustsFontForContentSizeCategory = false {
        didSet { synchronizeLabelStyle(restartMotion: true) }
    }

    /// Current caller-requested playback state.
    public private(set) var playbackState: ITextPlaybackState = .playing

    /// Immutable snapshot owned by the view.
    private var storedAttributedText = NSAttributedString(string: "")

    /// The visible or first moving text copy.
    private let primaryLabel = ITextStyledLabel()

    /// The repeated moving text copy.
    private let repeatedLabel = ITextStyledLabel()

    /// Shared deterministic motion engine.
    private let engine = _ITextMarqueeEngine(
        configuration: ITextMarqueeConfiguration.default.resolved,
        playbackState: .playing
    )

    /// Display-link clock active only while motion can advance.
    private let displayLink = _ITextDisplayLinkDriver()

    /// Scene-aware lifecycle source shared with the other UIKit timing controls.
    private lazy var sceneLifecycleObserver = _ITextUIKitSceneLifecycleObserver { [weak self] isActive in
        self?.applyEnvironmentState(isActive)
    }

    /// Latest deterministic motion state.
    private var snapshot = _ITextMarqueeSnapshot(
        offset: 0,
        isOverflowing: false,
        playbackState: .playing
    )

    /// Last measured full text width.
    private var contentWidth: CGFloat = 0

    /// Last physical layout direction used to place copies.
    private var lastLayoutDirection: UIUserInterfaceLayoutDirection?

    /// Creates an empty marquee view.
    ///
    /// - Parameter frame: Initial frame supplied by UIKit.
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    /// Creates a marquee view with initial content.
    ///
    /// - Parameters:
    ///   - text: An already-localized plain string.
    ///   - configuration: Marquee speed, spacing, and initial delay.
    ///   - playbackState: Initial caller-requested playback state.
    public convenience init(
        text: String,
        configuration: ITextMarqueeConfiguration = .default,
        playbackState: ITextPlaybackState = .playing
    ) {
        self.init(frame: .zero)
        self.configuration = configuration
        engine.updateConfiguration(configuration.resolved)
        self.text = text
        setPlaybackState(playbackState)
    }

    /// Creates a marquee view with initial attributed content.
    ///
    /// - Parameters:
    ///   - attributedText: An already-localized attributed value with single-line semantics.
    ///   - configuration: Marquee speed, spacing, and initial delay.
    ///   - playbackState: Initial caller-requested playback state.
    public convenience init(
        attributedText: NSAttributedString,
        configuration: ITextMarqueeConfiguration = .default,
        playbackState: ITextPlaybackState = .playing
    ) {
        self.init(frame: .zero)
        self.configuration = configuration
        engine.updateConfiguration(configuration.resolved)
        self.attributedText = attributedText
        setPlaybackState(playbackState)
    }

    /// Creates a marquee view from an archived interface description.
    ///
    /// - Parameter coder: Decoder supplied by UIKit.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    /// Removes notification observation and frame delivery.
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Starts from semantic leading and reapplies the complete initial delay.
    ///
    /// Calling `start()` while paused discards paused progress. Use ``resume()`` to continue from
    /// the exact frozen offset.
    public func start() {
        engine.setPlaybackState(.stopped)
        setPlaybackState(.playing)
    }

    /// Freezes the exact current marquee offset or remaining initial delay.
    public func pause() {
        setPlaybackState(.paused)
    }

    /// Continues from the exact frozen offset or remaining initial delay.
    ///
    /// Calling this method outside the paused state is a no-op.
    public func resume() {
        guard playbackState == .paused else { return }
        setPlaybackState(.playing)
    }

    /// Stops movement, discards saved progress, and returns text to semantic leading.
    public func stop() {
        setPlaybackState(.stopped)
    }

    /// Measures text, updates overflow state, and positions static or moving copies.
    public override func layoutSubviews() {
        super.layoutSubviews()
        contentWidth = measuredTextSize.width
        engine.updateMetrics(contentWidth: contentWidth, viewportWidth: bounds.width)
        snapshot = engine.snapshot

        let direction = effectiveUserInterfaceLayoutDirection
        if direction != lastLayoutDirection {
            lastLayoutDirection = direction
            engine.restart()
            snapshot = engine.snapshot
        }

        let shouldMove = snapshot.isOverflowing
            && configuration.resolved.speed > 0
            && !UIAccessibility.isReduceMotionEnabled
            && snapshot.playbackState != .stopped

        if shouldMove {
            layoutMovingLabels(direction: direction)
        } else {
            layoutStaticLabel()
        }
        accessibilityLabel = storedAttributedText.string
        reconcileDisplayLink()
    }

    /// The natural single-line text size.
    public override var intrinsicContentSize: CGSize {
        measuredTextSize
    }

    /// Measures the single line within a caller-proposed size.
    ///
    /// - Parameter size: Maximum size proposed by UIKit.
    /// - Returns: Single-line marquee size constrained to the proposal.
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let natural = intrinsicContentSize
        return CGSize(
            width: size.width.isFinite ? min(natural.width, max(size.width, 0)) : natural.width,
            height: natural.height
        )
    }

    /// Updates window-driven playback eligibility without changing explicit state.
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        sceneLifecycleObserver.updateWindow(window)
    }

    /// Remeasures preferred-font content and restarts geometry-dependent motion after a Dynamic
    /// Type category change inherited from the view hierarchy.
    ///
    /// - Parameter previousTraitCollection: Traits active before the change.
    public override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard adjustsFontForContentSizeCategory,
              previousTraitCollection?.preferredContentSizeCategory
                != traitCollection.preferredContentSizeCategory else {
            return
        }
        invalidateIntrinsicContentSize()
        engine.restart()
        setNeedsLayout()
    }

    /// Installs labels, callbacks, accessibility, and lifecycle observation.
    private func commonInit() {
        clipsToBounds = true
        backgroundColor = .clear
        isAccessibilityElement = true

        for label in [primaryLabel, repeatedLabel] {
            label.backgroundColor = .clear
            label.numberOfLines = 1
            label.isAccessibilityElement = false
            label.isUserInteractionEnabled = false
            addSubview(label)
        }
        synchronizeLabelStyle(restartMotion: false)
        synchronizeLabelContent()

        engine.onSnapshotChanged = { [weak self] snapshot in
            self?.applySnapshot(snapshot)
            self?.reconcileDisplayLink()
        }
        displayLink.onFrame = { [weak self] elapsed in
            self?.engine.advance(by: elapsed)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    /// Applies a playback state and reconciles scheduling.
    ///
    /// - Parameter state: The new caller-requested state.
    private func setPlaybackState(_ state: ITextPlaybackState) {
        engine.setPlaybackState(state)
        playbackState = state
        applySnapshot(engine.snapshot)
        reconcileDisplayLink()
    }

    /// Applies one deterministic render snapshot.
    ///
    /// - Parameter snapshot: State emitted by the timing engine.
    private func applySnapshot(_ snapshot: _ITextMarqueeSnapshot) {
        self.snapshot = snapshot
        playbackState = snapshot.playbackState
        setNeedsLayout()
    }

    /// Replaces content with an immutable snapshot and restarts geometry-dependent motion.
    private func replaceAttributedText(_ value: NSAttributedString) {
        let snapshot = NSAttributedString(attributedString: value)
        guard !snapshot.isEqual(to: storedAttributedText) else { return }
        storedAttributedText = snapshot
        synchronizeLabelContent()
        engine.restart()
        applySnapshot(engine.snapshot)
        setNeedsLayout()
    }

    /// Synchronizes attributed text between both private copies.
    private func synchronizeLabelContent() {
        primaryLabel.attributedText = storedAttributedText
        repeatedLabel.attributedText = storedAttributedText
        accessibilityLabel = storedAttributedText.string
        invalidateIntrinsicContentSize()
    }

    /// Synchronizes public typography with both private labels.
    ///
    /// - Parameter restartMotion: Whether geometry-dependent motion should restart.
    private func synchronizeLabelStyle(restartMotion: Bool) {
        for label in [primaryLabel, repeatedLabel] {
            label.font = font
            label.textColor = textColor
            label.textStyle = textStyle
            label.textAlignment = textAlignment
            label.adjustsFontForContentSizeCategory = adjustsFontForContentSizeCategory
        }
        // UILabel can rebuild its attributed presentation when defaults change. Reassign the
        // caller snapshot afterward so inline attributes continue to win over those defaults.
        synchronizeLabelContent()
        if restartMotion {
            engine.restart()
        }
        setNeedsLayout()
    }

    private func resolvedStrokeWidth(_ style: ITextUIKitStyle?) -> CGFloat {
        style?._resolved(
            isRightToLeft: effectiveUserInterfaceLayoutDirection == .rightToLeft
        ).stroke?.outwardWidth ?? 0
    }

    /// Measures the complete untruncated line independently from the labels' current frames.
    private var measuredTextSize: CGSize {
        guard storedAttributedText.length > 0 else { return .zero }
        let size = primaryLabel.sizeThatFits(CGSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        ))
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }

    /// Renders one static, tail-truncated accessibility representation.
    private func layoutStaticLabel() {
        primaryLabel.frame = bounds
        primaryLabel.lineBreakMode = .byTruncatingTail
        primaryLabel.isHidden = false
        repeatedLabel.isHidden = true
    }

    /// Positions repeated full-width labels for the current semantic travel offset.
    ///
    /// - Parameter direction: Current physical interface direction.
    private func layoutMovingLabels(direction: UIUserInterfaceLayoutDirection) {
        primaryLabel.lineBreakMode = .byClipping
        repeatedLabel.lineBreakMode = .byClipping
        primaryLabel.isHidden = false
        repeatedLabel.isHidden = false

        let distance = contentWidth + configuration.resolved.spacing
        let offset = snapshot.offset
        let startX = direction == .rightToLeft ? bounds.width - contentWidth : 0
        let primaryX: CGFloat
        let repeatedX: CGFloat
        if direction == .rightToLeft {
            primaryX = startX + offset
            repeatedX = startX - distance + offset
        } else {
            primaryX = startX - offset
            repeatedX = startX + distance - offset
        }

        primaryLabel.frame = CGRect(
            x: primaryX,
            y: 0,
            width: contentWidth,
            height: bounds.height
        )
        repeatedLabel.frame = CGRect(
            x: repeatedX,
            y: 0,
            width: contentWidth,
            height: bounds.height
        )
    }

    /// Applies current window-scene visibility to the timing engine.
    private func applyEnvironmentState(_ isActive: Bool) {
        engine.setEnvironmentActive(isActive)
        engine.setMotionAllowed(!UIAccessibility.isReduceMotionEnabled)
        reconcileDisplayLink()
    }

    /// Runs frame delivery only while elapsed time can change state.
    private func reconcileDisplayLink() {
        if engine.shouldAdvance {
            displayLink.start()
        } else {
            displayLink.stop()
        }
    }

    /// Applies current Reduce Motion behavior and reconciles frame delivery.
    @objc private func reduceMotionDidChange() {
        engine.setMotionAllowed(!UIAccessibility.isReduceMotionEnabled)
        snapshot = engine.snapshot
        reconcileDisplayLink()
        setNeedsLayout()
    }
}
