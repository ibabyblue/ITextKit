import UIKit

/// A UIKit view that automatically rotates through plain or attributed text values.
///
/// Two private labels render the outgoing and entering text so position, opacity, and intrinsic
/// height can pause at exact transition progress. The view never controls ancestor constraints or
/// calls `layoutIfNeeded()` on its superview.
@MainActor
public final class ITextRotatorView: UIView {
    /// The ordered, already-localized plain strings displayed by the view.
    ///
    /// Setting this property replaces rich content and discards its attributes. Reading it returns
    /// the plain characters of the current rich content.
    public var texts: [String] {
        get { storedAttributedTexts.map(\.string) }
        set { replaceAttributedTexts(newValue.map(NSAttributedString.init(string:))) }
    }

    /// The ordered, already-localized attributed values displayed by the view.
    ///
    /// Assignment takes immutable snapshots. Any content or attribute change resets display to the
    /// first item and starts a complete interval without changing explicit playback state.
    public var attributedTexts: [NSAttributedString] {
        get { storedAttributedTexts.map(NSAttributedString.init(attributedString:)) }
        set { replaceAttributedTexts(newValue) }
    }

    /// Shared rotation timing.
    public var configuration: ITextRotatorConfiguration = .default {
        didSet {
            guard configuration != oldValue else { return }
            engine.updateConfiguration(configuration.resolved)
            applySnapshot(engine.snapshot)
            reconcileDisplayLink()
        }
    }

    /// The action invoked after a new text finishes settling.
    ///
    /// Initial display, pausing, and stopping an in-flight transition remain silent.
    public var onTextChange: ((Int, String) -> Void)?

    /// The font applied to both private labels.
    public var font: UIFont = .preferredFont(forTextStyle: .body) {
        didSet { synchronizeLabelStyle() }
    }

    /// The dynamic text color applied to both private labels.
    public var textColor: UIColor = .label {
        didSet { synchronizeLabelStyle() }
    }

    /// Horizontal alignment applied to both private labels.
    public var textAlignment: NSTextAlignment = .natural {
        didSet { synchronizeLabelStyle() }
    }

    /// Maximum rendered line count. Zero allows any number of lines.
    public var numberOfLines: Int = 0 {
        didSet { synchronizeLabelStyle() }
    }

    /// Line wrapping or truncation behavior applied to both private labels.
    public var lineBreakMode: NSLineBreakMode = .byWordWrapping {
        didSet { synchronizeLabelStyle() }
    }

    /// Whether preferred text styles update with the content-size category.
    public var adjustsFontForContentSizeCategory = false {
        didSet { synchronizeLabelStyle() }
    }

    /// Current caller-requested playback state.
    public private(set) var playbackState: ITextPlaybackState = .playing

    /// Immutable snapshots owned by the view.
    private var storedAttributedTexts: [NSAttributedString] = []

    /// The last fully settled text label.
    private let currentLabel = UILabel()

    /// The text label entering during a transition.
    private let nextLabel = UILabel()

    /// Shared deterministic timing engine.
    private let engine = _ITextRotatorEngine(
        itemCount: 0,
        configuration: ITextRotatorConfiguration.default.resolved,
        playbackState: .playing
    )

    /// Display-link clock active only while timing can advance.
    private let displayLink = _ITextDisplayLinkDriver()

    /// Latest transition state rendered by the labels.
    private var snapshot = _ITextRotatorSnapshot(
        currentIndex: 0,
        nextIndex: nil,
        progress: 0,
        playbackState: .playing
    )

    /// Last bounds width used for multiline intrinsic-height measurement.
    private var lastMeasuredBoundsWidth: CGFloat = 0

    /// Whether application lifecycle currently permits advancement.
    private var applicationIsActive = true

    /// Creates an empty rotating text view.
    ///
    /// - Parameter frame: Initial frame supplied by UIKit.
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    /// Creates a rotating text view with initial content.
    ///
    /// - Parameters:
    ///   - texts: Ordered, already-localized strings.
    ///   - configuration: Rotation timing.
    ///   - playbackState: Initial caller-requested playback state.
    public convenience init(
        texts: [String],
        configuration: ITextRotatorConfiguration = .default,
        playbackState: ITextPlaybackState = .playing
    ) {
        self.init(frame: .zero)
        self.configuration = configuration
        engine.updateConfiguration(configuration.resolved)
        self.texts = texts
        setPlaybackState(playbackState)
    }

    /// Creates a rotating text view with initial attributed content.
    ///
    /// - Parameters:
    ///   - attributedTexts: Ordered, already-localized attributed values.
    ///   - configuration: Rotation timing.
    ///   - playbackState: Initial caller-requested playback state.
    public convenience init(
        attributedTexts: [NSAttributedString],
        configuration: ITextRotatorConfiguration = .default,
        playbackState: ITextPlaybackState = .playing
    ) {
        self.init(frame: .zero)
        self.configuration = configuration
        engine.updateConfiguration(configuration.resolved)
        self.attributedTexts = attributedTexts
        setPlaybackState(playbackState)
    }

    /// Creates a rotating text view from an archived interface description.
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

    /// Starts from a stable state and a complete interval.
    ///
    /// Calling `start()` while paused intentionally discards paused progress. Use ``resume()`` to
    /// continue from an exact frozen position.
    public func start() {
        engine.setPlaybackState(.stopped)
        setPlaybackState(.playing)
    }

    /// Freezes remaining delay or in-flight transition progress.
    public func pause() {
        setPlaybackState(.paused)
    }

    /// Continues from an exact paused delay or transition position.
    ///
    /// Calling this method outside the paused state is a no-op.
    public func resume() {
        guard playbackState == .paused else { return }
        setPlaybackState(.playing)
    }

    /// Stops playback, discards saved progress, and keeps the last fully settled text.
    public func stop() {
        setPlaybackState(.stopped)
    }

    /// Sizes both text labels and applies the current transition snapshot.
    public override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.width != lastMeasuredBoundsWidth {
            lastMeasuredBoundsWidth = bounds.width
            invalidateIntrinsicContentSize()
        }

        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let transition = _ITextRotatorTransitionPresentation(
            linearProgress: snapshot.progress,
            reduceMotion: reduceMotion
        )
        let currentHeight = layoutLabelAtTop(currentLabel)
        let nextHeight = layoutLabelAtTop(nextLabel)

        if let _ = snapshot.nextIndex {
            currentLabel.alpha = CGFloat(transition.outgoing.opacity)
            nextLabel.alpha = CGFloat(transition.incoming.opacity)
            currentLabel.transform = CGAffineTransform(
                translationX: 0,
                y: CGFloat(transition.outgoing.verticalOffsetFactor) * currentHeight
            )
            nextLabel.transform = CGAffineTransform(
                translationX: 0,
                y: CGFloat(transition.incoming.verticalOffsetFactor) * nextHeight
            )
            nextLabel.isHidden = false
        } else {
            currentLabel.alpha = 1
            currentLabel.transform = .identity
            nextLabel.alpha = 0
            nextLabel.transform = .identity
            nextLabel.isHidden = true
        }
    }

    /// The current text's natural size, or the larger old/new size during a transition.
    public override var intrinsicContentSize: CGSize {
        measuredContentSize(constrainedTo: bounds.width > 0 ? bounds.width : nil)
    }

    /// Measures content using the caller-proposed width.
    ///
    /// - Parameter size: Maximum size proposed by UIKit.
    /// - Returns: Size required by the current transition phase.
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = size.width.isFinite && size.width > 0 ? size.width : nil
        return measuredContentSize(constrainedTo: width)
    }

    /// Updates window-driven playback eligibility without changing explicit state.
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        applyEnvironmentState()
    }

    /// Installs labels, callbacks, accessibility, and lifecycle observation.
    private func commonInit() {
        clipsToBounds = true
        backgroundColor = .clear
        isAccessibilityElement = true

        for label in [currentLabel, nextLabel] {
            label.backgroundColor = .clear
            label.isAccessibilityElement = false
            label.isUserInteractionEnabled = false
            addSubview(label)
        }
        synchronizeLabelStyle()

        applicationIsActive = UIApplication.shared.applicationState == .active
        engine.onSnapshotChanged = { [weak self] snapshot in
            self?.applySnapshot(snapshot)
            self?.reconcileDisplayLink()
        }
        engine.onItemSettled = { [weak self] index in
            guard let self, self.storedAttributedTexts.indices.contains(index) else { return }
            self.onTextChange?(index, self.storedAttributedTexts[index].string)
        }
        displayLink.onFrame = { [weak self] elapsed in
            self?.engine.advance(by: elapsed)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )

        applySnapshot(engine.snapshot)
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
    private func applySnapshot(_ snapshot: _ITextRotatorSnapshot) {
        self.snapshot = snapshot
        playbackState = snapshot.playbackState
        currentLabel.attributedText = attributedText(at: snapshot.currentIndex)
        nextLabel.attributedText = snapshot.nextIndex.flatMap(attributedText(at:))
        if snapshot.nextIndex == nil {
            currentLabel.alpha = 1
            currentLabel.transform = .identity
            nextLabel.alpha = 0
            nextLabel.transform = .identity
            nextLabel.isHidden = true
        }
        accessibilityLabel = currentLabel.attributedText?.string
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    /// Replaces content with immutable snapshots and restarts from the first item when changed.
    ///
    /// - Parameter values: Caller-owned attributed values.
    private func replaceAttributedTexts(_ values: [NSAttributedString]) {
        let snapshots = values.map(NSAttributedString.init(attributedString:))
        guard !attributedTextCollectionsEqual(snapshots, storedAttributedTexts) else { return }
        storedAttributedTexts = snapshots
        engine.updateItemCount(snapshots.count)
        applySnapshot(engine.snapshot)
        reconcileDisplayLink()
    }

    /// Compares characters and every native attribute.
    private func attributedTextCollectionsEqual(
        _ lhs: [NSAttributedString],
        _ rhs: [NSAttributedString]
    ) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) }
    }

    /// Returns attributed text safely for an engine-provided index.
    ///
    /// - Parameter index: Requested array position.
    /// - Returns: Attributed text at the index, or `nil` when unavailable.
    private func attributedText(at index: Int) -> NSAttributedString? {
        storedAttributedTexts.indices.contains(index) ? storedAttributedTexts[index] : nil
    }

    /// Synchronizes public typography with both private labels.
    private func synchronizeLabelStyle() {
        for label in [currentLabel, nextLabel] {
            label.font = font
            label.textColor = textColor
            label.textAlignment = textAlignment
            label.numberOfLines = numberOfLines
            label.lineBreakMode = lineBreakMode
            label.adjustsFontForContentSizeCategory = adjustsFontForContentSizeCategory
        }
        // UILabel can rebuild its attributed presentation when defaults change. Reassign the
        // caller snapshot afterward so inline attributes continue to win over those defaults.
        applySnapshot(engine.snapshot)
    }

    /// Sizes one label using its own text height and places its untransformed origin at the top.
    ///
    /// `bounds` and `center` remain well-defined while a transform is active. Assigning `frame`
    /// in that state is undefined and previously made the visible text jump in the wrong direction.
    ///
    /// - Parameter label: The outgoing or incoming text layer.
    /// - Returns: The layer's natural height for vertical transition travel.
    private func layoutLabelAtTop(_ label: UILabel) -> CGFloat {
        let constraint = CGSize(
            width: bounds.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        let height = label.sizeThatFits(constraint).height
        label.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: height)
        label.center = CGPoint(x: bounds.midX, y: height / 2)
        return height
    }

    /// Measures the settled label or the maximum of both transitioning labels.
    ///
    /// - Parameter width: Optional wrapping width.
    /// - Returns: Required content size.
    private func measuredContentSize(constrainedTo width: CGFloat?) -> CGSize {
        let constraint = CGSize(
            width: width ?? CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        let currentSize = currentLabel.sizeThatFits(constraint)
        guard snapshot.nextIndex != nil else { return currentSize }
        let nextSize = nextLabel.sizeThatFits(constraint)
        return CGSize(
            width: max(currentSize.width, nextSize.width),
            height: max(currentSize.height, nextSize.height)
        )
    }

    /// Applies current window and application visibility to the timing engine.
    private func applyEnvironmentState() {
        engine.setEnvironmentActive(window != nil && applicationIsActive)
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

    /// Continues lifecycle-suspended progress when the application becomes active.
    @objc private func applicationDidBecomeActive() {
        applicationIsActive = true
        applyEnvironmentState()
    }

    /// Freezes lifecycle-suspended progress before the application resigns active.
    @objc private func applicationWillResignActive() {
        applicationIsActive = false
        applyEnvironmentState()
    }

    /// Re-renders an in-flight transition using the current motion preference.
    @objc private func reduceMotionDidChange() {
        setNeedsLayout()
    }
}
