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
            animationNeedsRebuild = true
            if configuration.resolved.spacing != oldValue.resolved.spacing {
                geometryIsDirty = true
            }
            engine.updateConfiguration(configuration.resolved)
            applySnapshot(engine.snapshot)
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
                invalidateMeasurementAndGeometry()
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

    /// Fixed viewport-sized container translated during steady travel.
    private let motionContainerView = UIView()

    /// Shared deterministic motion engine.
    private let engine = _ITextMarqueeEngine(
        configuration: ITextMarqueeConfiguration.default.resolved,
        playbackState: .playing
    )

    /// Compositor adapter that owns the motion container's single travel animation.
    private let layerAnimator = _ITextMarqueeLayerAnimator()

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

    /// Cached natural single-line text size.
    private var cachedMeasuredTextSize = CGSize.zero

    /// Whether content-dependent measurement must be rebuilt.
    private var measurementIsDirty = true

    /// Whether fixed container and copy frames must be rebuilt.
    private var geometryIsDirty = true

    /// Last viewport size used to prepare fixed geometry.
    private var preparedBoundsSize = CGSize(width: -1, height: -1)

    /// Last physical layout direction used to place copies.
    private var lastLayoutDirection: UIUserInterfaceLayoutDirection?

    /// Presentation mode used when the current copy frames were prepared.
    private var preparedForMovingPresentation: Bool?

    /// Whether the next eligible active presentation must install a fresh travel plan.
    private var animationNeedsRebuild = true

    /// Number of full untruncated measurements performed by this view.
    private(set) var _measurementGeneration: UInt64 = 0

    /// The two private visual copies exposed only to internal regression tests.
    var _movingLabels: [ITextStyledLabel] {
        [primaryLabel, repeatedLabel]
    }

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
        let direction = effectiveUserInterfaceLayoutDirection
        if direction != lastLayoutDirection {
            lastLayoutDirection = direction
            geometryIsDirty = true
            animationNeedsRebuild = true
            layerAnimator.stop()
            engine.restart()
            snapshot = engine.snapshot
        }

        if preparedBoundsSize != bounds.size {
            preparedBoundsSize = bounds.size
            geometryIsDirty = true
        }

        if geometryIsDirty {
            prepareGeometry(direction: direction)
        }
        snapshot = engine.snapshot

        let shouldMove = shouldMove(using: snapshot)

        if shouldMove {
            showMovingLabels()
        } else {
            showStaticLabel()
        }
        accessibilityLabel = storedAttributedText.string
        reconcileLayerAnimation()
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
        let contentSizeChanged = adjustsFontForContentSizeCategory
            && previousTraitCollection?.preferredContentSizeCategory
                != traitCollection.preferredContentSizeCategory
        let displayScaleChanged = previousTraitCollection != nil
            && previousTraitCollection?.displayScale != traitCollection.displayScale
        guard contentSizeChanged || displayScaleChanged else {
            return
        }
        invalidateIntrinsicContentSize()
        invalidateMeasurementAndGeometry()
        engine.restart()
        setNeedsLayout()
    }

    /// Installs labels, callbacks, accessibility, and lifecycle observation.
    private func commonInit() {
        clipsToBounds = true
        backgroundColor = .clear
        isAccessibilityElement = true

        motionContainerView.backgroundColor = .clear
        motionContainerView.isUserInteractionEnabled = false
        addSubview(motionContainerView)

        for label in [primaryLabel, repeatedLabel] {
            label.backgroundColor = .clear
            label.numberOfLines = 1
            label.isAccessibilityElement = false
            label.isUserInteractionEnabled = false
            motionContainerView.addSubview(label)
        }
        synchronizeLabelStyle(restartMotion: false)
        synchronizeLabelContent()

        engine.onSnapshotChanged = { [weak self] snapshot in
            self?.applySnapshot(snapshot)
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
        reconcileLayerAnimation()
    }

    /// Applies one deterministic render snapshot.
    ///
    /// - Parameter snapshot: State emitted by the timing engine.
    private func applySnapshot(_ snapshot: _ITextMarqueeSnapshot) {
        self.snapshot = snapshot
        playbackState = snapshot.playbackState
        if preparedForMovingPresentation != shouldMove(using: snapshot) {
            geometryIsDirty = true
        }
        if geometryIsDirty || preparedBoundsSize != bounds.size {
            setNeedsLayout()
        } else {
            applyCurrentPresentation()
        }
    }

    /// Replaces content with an immutable snapshot and restarts geometry-dependent motion.
    private func replaceAttributedText(_ value: NSAttributedString) {
        let snapshot = NSAttributedString(attributedString: value)
        guard !snapshot.isEqual(to: storedAttributedText) else { return }
        storedAttributedText = snapshot
        synchronizeLabelContent()
        invalidateMeasurementAndGeometry()
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
            invalidateMeasurementAndGeometry()
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
        guard measurementIsDirty else { return cachedMeasuredTextSize }
        measurementIsDirty = false
        guard storedAttributedText.length > 0 else {
            cachedMeasuredTextSize = .zero
            return .zero
        }
        _measurementGeneration &+= 1
        let size = primaryLabel.sizeThatFits(CGSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        ))
        cachedMeasuredTextSize = CGSize(
            width: ceil(size.width),
            height: ceil(size.height)
        )
        return cachedMeasuredTextSize
    }

    /// Renders one static, tail-truncated accessibility representation.
    private func showStaticLabel() {
        motionContainerView.transform = .identity
        primaryLabel.frame = motionContainerView.bounds
        primaryLabel.lineBreakMode = .byTruncatingTail
        primaryLabel.isHidden = false
        repeatedLabel.isHidden = true
    }

    /// Reveals the two fixed full-width labels prepared for compositor travel.
    private func showMovingLabels() {
        primaryLabel.lineBreakMode = .byClipping
        repeatedLabel.lineBreakMode = .byClipping
        primaryLabel.isHidden = false
        repeatedLabel.isHidden = false
    }

    /// Rebuilds measurement and fixed copy frames after a real geometry change.
    private func prepareGeometry(direction: UIUserInterfaceLayoutDirection) {
        motionContainerView.transform = .identity
        motionContainerView.frame = bounds
        contentWidth = measuredTextSize.width
        engine.updateMetrics(contentWidth: contentWidth, viewportWidth: bounds.width)
        snapshot = engine.snapshot
        geometryIsDirty = false
        animationNeedsRebuild = true

        let shouldMove = shouldMove(using: snapshot)
        preparedForMovingPresentation = shouldMove
        if shouldMove {
            let distance = contentWidth + configuration.resolved.spacing
            let startX = direction == .rightToLeft
                ? bounds.width - contentWidth
                : 0
            let repeatedX = direction == .rightToLeft
                ? startX - distance
                : startX + distance
            primaryLabel.frame = CGRect(
                x: startX,
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
        } else {
            primaryLabel.frame = bounds
        }
    }

    /// Applies the current state without measuring or changing copy frames.
    private func applyCurrentPresentation() {
        let shouldMove = shouldMove(using: snapshot)
        if shouldMove {
            showMovingLabels()
        } else {
            showStaticLabel()
        }
        reconcileLayerAnimation()
    }

    /// Resolves whether the current inputs require the repeated moving presentation.
    private func shouldMove(using snapshot: _ITextMarqueeSnapshot) -> Bool {
        snapshot.isOverflowing
            && configuration.resolved.speed > 0
            && engine.isMotionAllowed
            && !UIAccessibility.isReduceMotionEnabled
            && snapshot.playbackState != .stopped
    }

    /// Marks cached measurement and fixed frames stale.
    private func invalidateMeasurementAndGeometry() {
        measurementIsDirty = true
        geometryIsDirty = true
        animationNeedsRebuild = true
        layerAnimator.stop()
    }

    /// Applies current window-scene visibility to the timing engine.
    private func applyEnvironmentState(_ isActive: Bool) {
        engine.setEnvironmentActive(isActive)
        engine.setMotionAllowed(!UIAccessibility.isReduceMotionEnabled)
        if !isActive, window == nil {
            animationNeedsRebuild = true
        }
        reconcileLayerAnimation()
    }

    /// Applies one discrete engine/lifecycle transition to the compositor adapter.
    private func reconcileLayerAnimation() {
        guard !geometryIsDirty else { return }
        let direction = effectiveUserInterfaceLayoutDirection
        guard shouldMove(using: snapshot) else {
            layerAnimator.stop()
            return
        }

        guard engine.isEnvironmentActive else {
            if window == nil {
                layerAnimator.stop()
                animationNeedsRebuild = true
            } else if layerAnimator.hasActiveTravelAnimation {
                layerAnimator.pause()
            } else {
                layerAnimator.present(
                    offset: snapshot.offset,
                    direction: direction,
                    on: motionContainerView.layer
                )
            }
            return
        }

        switch playbackState {
        case .stopped:
            layerAnimator.stop()
        case .paused:
            if layerAnimator.hasActiveTravelAnimation {
                layerAnimator.pause()
            } else {
                layerAnimator.present(
                    offset: snapshot.offset,
                    direction: direction,
                    on: motionContainerView.layer
                )
            }
        case .playing:
            if animationNeedsRebuild || !layerAnimator.hasActiveTravelAnimation {
                guard let plan = engine.motionPlan else { return }
                layerAnimator.install(
                    on: motionContainerView.layer,
                    plan: plan,
                    direction: direction
                )
                animationNeedsRebuild = false
            } else {
                layerAnimator.resume()
            }
        }
    }

    /// Applies current Reduce Motion behavior and reconciles frame delivery.
    @objc private func reduceMotionDidChange() {
        engine.setMotionAllowed(!UIAccessibility.isReduceMotionEnabled)
        snapshot = engine.snapshot
        animationNeedsRebuild = true
        reconcileLayerAnimation()
        setNeedsLayout()
    }

    /// Current travel animation exposed only to internal regression tests.
    var _travelAnimation: CABasicAnimation? {
        motionContainerView.layer.animation(
            forKey: _ITextMarqueeLayerAnimator.animationKey
        ) as? CABasicAnimation
    }

    /// Whether the compositor currently owns a travel animation resource.
    var _hasActiveTravelAnimation: Bool {
        layerAnimator.hasActiveTravelAnimation
    }

    /// Motion-layer local time exposed only to internal regression tests.
    var _motionLayerTimeOffset: CFTimeInterval {
        motionContainerView.layer.timeOffset
    }

    /// Motion-layer timing speed exposed only to internal regression tests.
    var _motionLayerSpeed: Float {
        motionContainerView.layer.speed
    }

    /// Current compositor presentation translation exposed only to internal regression tests.
    var _motionPresentationTranslationX: CGFloat? {
        motionContainerView.layer.presentation()?.affineTransform().tx
    }
}
