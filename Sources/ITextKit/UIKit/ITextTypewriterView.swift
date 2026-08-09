import UIKit

/// A UIKit view that reveals plain or attributed text one complete character at a time.
///
/// The intrinsic width and height grow with the visible prefix. Callers provide any maximum width
/// through normal Auto Layout constraints. The view freezes automatically outside an active window
/// and does not expose playback controls.
@MainActor
public final class ITextTypewriterView: UIView {
    /// The complete plain text represented by the view.
    ///
    /// Setting this property replaces rich content and discards its attributes. Reading it strips
    /// attributes from the current immutable content snapshot.
    public var text: String {
        get { storedAttributedText.string }
        set { replaceAttributedText(NSAttributedString(string: newValue)) }
    }

    /// The complete attributed text represented by the view.
    ///
    /// Assignment takes an immutable snapshot. An actual character or attribute change restarts
    /// progressive reveal; an equal value is ignored.
    public var attributedText: NSAttributedString {
        get { NSAttributedString(attributedString: storedAttributedText) }
        set { replaceAttributedText(newValue) }
    }

    /// Character speed and initial delay.
    ///
    /// An actual configuration change restarts current content from an empty prefix.
    public var configuration: ITextTypewriterConfiguration = .default {
        didSet {
            guard configuration != oldValue else { return }
            engine.updateConfiguration(configuration.resolved)
            applySnapshot(engine.snapshot)
            reconcileDisplayLink()
        }
    }

    /// Default font used by ranges without an inline font attribute.
    public var font: UIFont = .preferredFont(forTextStyle: .body) {
        didSet { synchronizeLabelStyle() }
    }

    /// Default color used by ranges without an inline foreground color.
    public var textColor: UIColor = .label {
        didSet { synchronizeLabelStyle() }
    }

    /// Horizontal alignment used when content has no inline paragraph alignment.
    public var textAlignment: NSTextAlignment = .natural {
        didSet { synchronizeLabelStyle() }
    }

    /// Maximum rendered line count. Zero allows any number of lines.
    public var numberOfLines: Int = 0 {
        didSet { synchronizeLabelStyle() }
    }

    /// Native wrapping or truncation behavior.
    public var lineBreakMode: NSLineBreakMode = .byWordWrapping {
        didSet { synchronizeLabelStyle() }
    }

    /// Whether preferred text styles update with the content-size category.
    public var adjustsFontForContentSizeCategory = false {
        didSet { synchronizeLabelStyle() }
    }

    /// Immutable complete content owned by the view.
    private var storedAttributedText = NSAttributedString(string: "")

    /// UTF-16 ranges for complete extended grapheme clusters.
    private var characterRanges: [NSRange] = []

    /// The only visual text label; the view itself owns accessibility.
    private let label = UILabel()

    /// Independent deterministic reveal engine.
    private let engine = _ITextTypewriterEngine(
        unitCount: 0,
        configuration: ITextTypewriterConfiguration.default.resolved
    )

    /// Display-link clock active only while another unit can become visible.
    private let displayLink = _ITextDisplayLinkDriver()

    /// Latest reveal state rendered by the label.
    private var snapshot = _ITextTypewriterSnapshot(revealedCount: 0, unitCount: 0)

    /// Last width used for wrapping-dependent intrinsic height.
    private var lastMeasuredBoundsWidth: CGFloat = 0

    /// Whether application lifecycle currently permits advancement.
    private var applicationIsActive = true

    /// Creates an empty typewriter view.
    ///
    /// - Parameter frame: Initial frame supplied by UIKit.
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    /// Creates a typewriter view with plain content.
    ///
    /// - Parameters:
    ///   - text: An already-localized plain string.
    ///   - configuration: Character speed and initial delay.
    public convenience init(
        text: String,
        configuration: ITextTypewriterConfiguration = .default
    ) {
        self.init(frame: .zero)
        self.configuration = configuration
        engine.updateConfiguration(configuration.resolved)
        self.text = text
    }

    /// Creates a typewriter view with attributed content.
    ///
    /// - Parameters:
    ///   - attributedText: An already-localized attributed value.
    ///   - configuration: Character speed and initial delay.
    public convenience init(
        attributedText: NSAttributedString,
        configuration: ITextTypewriterConfiguration = .default
    ) {
        self.init(frame: .zero)
        self.configuration = configuration
        engine.updateConfiguration(configuration.resolved)
        self.attributedText = attributedText
    }

    /// Creates a typewriter view from an archived interface description.
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

    /// Positions the current prefix and updates wrapping-dependent intrinsic height.
    public override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.width != lastMeasuredBoundsWidth {
            lastMeasuredBoundsWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
        label.frame = bounds
    }

    /// The natural current-prefix width and its height at the externally constrained bounds width.
    public override var intrinsicContentSize: CGSize {
        measuredContentSize(currentBoundsWidth: bounds.width)
    }

    /// Measures the visible prefix within a caller-proposed maximum width.
    ///
    /// - Parameter size: Maximum size proposed by UIKit.
    /// - Returns: Current-prefix size using native label wrapping.
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard label.attributedText?.length ?? 0 > 0 else { return .zero }
        let natural = naturalContentSize
        guard size.width.isFinite else { return natural }
        let width = min(natural.width, max(size.width, 0))
        guard width > 0 else { return .zero }
        let measured = label.sizeThatFits(CGSize(
            width: width,
            height: CGFloat.greatestFiniteMagnitude
        ))
        return CGSize(width: ceil(width), height: ceil(measured.height))
    }

    /// Applies window-driven timing eligibility.
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        applyEnvironmentState()
    }

    /// Installs the label, deterministic callbacks, accessibility, and lifecycle observation.
    private func commonInit() {
        clipsToBounds = true
        backgroundColor = .clear
        isAccessibilityElement = true
        isUserInteractionEnabled = false

        label.backgroundColor = .clear
        label.isAccessibilityElement = false
        label.isUserInteractionEnabled = false
        addSubview(label)
        synchronizeLabelStyle()

        applicationIsActive = UIApplication.shared.applicationState == .active
        engine.onSnapshotChanged = { [weak self] snapshot in
            self?.applySnapshot(snapshot)
            self?.reconcileDisplayLink()
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )

        engine.setMotionAllowed(!UIAccessibility.isReduceMotionEnabled)
        applySnapshot(engine.snapshot)
    }

    /// Replaces content with an immutable snapshot when characters or attributes actually change.
    private func replaceAttributedText(_ value: NSAttributedString) {
        let immutable = NSAttributedString(attributedString: value)
        guard !immutable.isEqual(to: storedAttributedText) else { return }
        storedAttributedText = immutable
        characterRanges = Self.makeCharacterRanges(for: immutable.string)
        accessibilityLabel = immutable.string
        engine.updateUnitCount(characterRanges.count)
        applySnapshot(engine.snapshot)
        reconcileDisplayLink()
    }

    /// Applies one render snapshot by slicing at a complete composed-character boundary.
    private func applySnapshot(_ snapshot: _ITextTypewriterSnapshot) {
        self.snapshot = snapshot
        label.attributedText = attributedPrefix(unitCount: snapshot.revealedCount)
        accessibilityLabel = storedAttributedText.string
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    /// Synchronizes public label defaults without resetting reveal progress.
    private func synchronizeLabelStyle() {
        label.font = font
        label.textColor = textColor
        label.textAlignment = textAlignment
        label.numberOfLines = numberOfLines
        label.lineBreakMode = lineBreakMode
        label.adjustsFontForContentSizeCategory = adjustsFontForContentSizeCategory
        // Reassignment after UILabel defaults change preserves inline attributed values.
        applySnapshot(engine.snapshot)
    }

    /// Returns the current rich prefix without splitting an extended grapheme cluster.
    private func attributedPrefix(unitCount: Int) -> NSAttributedString {
        let count = min(max(unitCount, 0), characterRanges.count)
        guard count > 0 else { return NSAttributedString(string: "") }
        let length = NSMaxRange(characterRanges[count - 1])
        return storedAttributedText.attributedSubstring(
            from: NSRange(location: 0, length: length)
        )
    }

    /// The visible prefix's unconstrained native size.
    private var naturalContentSize: CGSize {
        let measured = label.sizeThatFits(CGSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        ))
        return CGSize(width: ceil(measured.width), height: ceil(measured.height))
    }

    /// Resolves growing intrinsic width while using actual bounds only for wrapped height.
    private func measuredContentSize(currentBoundsWidth: CGFloat) -> CGSize {
        guard label.attributedText?.length ?? 0 > 0 else { return .zero }
        let natural = naturalContentSize
        let widthForHeight: CGFloat
        if currentBoundsWidth > 0, currentBoundsWidth < natural.width {
            widthForHeight = currentBoundsWidth
        } else {
            widthForHeight = natural.width
        }
        let measured = label.sizeThatFits(CGSize(
            width: widthForHeight,
            height: CGFloat.greatestFiniteMagnitude
        ))
        return CGSize(width: natural.width, height: ceil(measured.height))
    }

    /// Projects window and application visibility into the independent engine.
    private func applyEnvironmentState() {
        engine.setEnvironmentActive(window != nil && applicationIsActive)
        applySnapshot(engine.snapshot)
        reconcileDisplayLink()
    }

    /// Runs frame delivery only while elapsed time can reveal another unit.
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

    /// Reveals complete content when Reduce Motion becomes enabled without replaying on disable.
    @objc private func reduceMotionDidChange() {
        engine.setMotionAllowed(!UIAccessibility.isReduceMotionEnabled)
        applySnapshot(engine.snapshot)
        reconcileDisplayLink()
    }

    /// Remeasures the current prefix without changing revealed units.
    @objc private func contentSizeCategoryDidChange() {
        synchronizeLabelStyle()
    }

    /// Builds UTF-16 ranges for complete composed-character sequences.
    private static func makeCharacterRanges(for string: String) -> [NSRange] {
        let value = string as NSString
        var result: [NSRange] = []
        var location = 0
        while location < value.length {
            let range = value.rangeOfComposedCharacterSequence(at: location)
            result.append(range)
            location = NSMaxRange(range)
        }
        return result
    }
}
