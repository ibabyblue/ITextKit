import UIKit

/// A label that reveals a highlight-colored copy of its text through a moving band.
///
/// The label itself remains the only layout and accessibility owner. A private,
/// noninteractive ``ITextStyledLabel`` mirrors native text drawing properties, so plain and
/// attributed text retain `UILabel` layout, intrinsic sizing, Dynamic Type, and
/// multiline behavior. The copy replaces only its foreground color; caller-owned
/// attributed strings are never mutated.
///
/// Animation runs only while requested, nonempty, laid out in a window, visible
/// to motion accessibility settings, and configured with nonzero intensity.
/// Disabling and later re-enabling shimmer starts a complete sweep. Core Animation
/// advances frames without a timer, display link, or per-frame package callback.
@MainActor
public final class ITextShimmerLabel: ITextStyledLabel {
    /// Whether the caller requests a repeating highlight sweep.
    ///
    /// The default is `false`. Setting the same value is idempotent. Changing
    /// from `false` to `true` starts from the semantic leading or trailing edge
    /// when all content, layout, lifecycle, and Reduce Motion conditions permit.
    /// Changing to `false` immediately removes the private mask and animation.
    public var isShimmering = false {
        didSet {
            guard isShimmering != oldValue else { return }
            reconcileAnimation()
        }
    }

    /// Sweep timing, band width, opacity, and semantic direction.
    ///
    /// The default is ``ITextShimmerConfiguration/default``. The stored value
    /// preserves caller input; range clamping and non-finite fallbacks happen
    /// only when rendered. An actual change rebuilds any active animation from
    /// the beginning and updates the private highlight copy.
    public var configuration: ITextShimmerConfiguration = .default {
        didSet {
            guard configuration != oldValue else { return }
            synchronizeOverlayContent()
            rebuildAnimationIfNeeded()
        }
    }

    /// The dynamic color used only by the private highlight copy.
    ///
    /// The default is `UIColor.label`. Resolved configuration intensity is
    /// applied as this color's alpha. Assignment never changes `textColor` or
    /// the foreground attributes of caller-owned text.
    public var highlightColor: UIColor = .label {
        didSet {
            synchronizeOverlayContent()
        }
    }

    /// Fill and outline mirrored into the masked highlight copy.
    public override var textStyle: ITextUIKitStyle? {
        didSet { synchronizeOverlayContent() }
    }

    /// The only private visual copy; the receiver owns layout and accessibility.
    private let shimmerOverlayLabel: ITextStyledLabel

    /// Bounds used to construct the currently installed gradient animation.
    private var lastAnimatedBounds: CGRect = .null

    /// Physical direction used by the currently installed gradient animation.
    private var lastTravelDirection: ITextShimmerTravelDirection?

    /// Stable key that makes repeated reconciliation replace, rather than stack, animation.
    private let animationKey = "ITextKit.shimmer.position"

    /// Creates an empty shimmer-capable label with the supplied frame.
    ///
    /// Shimmer remains stopped until ``isShimmering`` becomes `true` and the
    /// label has text, nonempty bounds, a window, and motion permission.
    ///
    /// - Parameter frame: Initial frame in the superview's coordinate system.
    public override init(frame: CGRect) {
        shimmerOverlayLabel = ITextStyledLabel()
        super.init(frame: frame)
        setUp()
    }

    /// Creates a shimmer-capable label from an archived interface description.
    ///
    /// The decoded label remains stopped by default. Runtime drawing properties
    /// are mirrored into the private highlight copy during setup.
    ///
    /// - Parameter coder: Decoder supplied by UIKit.
    public required init?(coder: NSCoder) {
        shimmerOverlayLabel = ITextStyledLabel()
        super.init(coder: coder)
        setUp()
    }

    /// Removes the lifecycle and accessibility observations owned by this label.
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Plain text mirrored into the private highlight copy.
    ///
    /// Assignment preserves native `UILabel` sizing and accessibility behavior.
    /// Empty content removes any running shimmer; new nonempty content restarts
    /// it when ``isShimmering`` and the environment permit animation.
    public override var text: String? {
        didSet {
            synchronizeOverlayContent()
            reconcileAnimation()
        }
    }

    /// Attributed text copied before only the copy's foreground is replaced.
    ///
    /// Fonts, paragraph styles, kerning, decorations, and other attributes are
    /// retained. The input object is not mutated. Empty content stops shimmer.
    public override var attributedText: NSAttributedString? {
        didSet {
            synchronizeOverlayContent()
            reconcileAnimation()
        }
    }

    /// Default font mirrored for plain text and unattributed ranges.
    public override var font: UIFont! {
        didSet {
            synchronizeOverlayContent()
        }
    }

    /// Maximum line count mirrored into the private highlight copy.
    public override var numberOfLines: Int {
        didSet {
            shimmerOverlayLabel.numberOfLines = numberOfLines
        }
    }

    /// Native wrapping or truncation behavior mirrored into the highlight copy.
    public override var lineBreakMode: NSLineBreakMode {
        didSet {
            shimmerOverlayLabel.lineBreakMode = lineBreakMode
        }
    }

    /// Native horizontal alignment mirrored into the highlight copy.
    public override var textAlignment: NSTextAlignment {
        didSet {
            shimmerOverlayLabel.textAlignment = textAlignment
        }
    }

    /// Baseline adjustment used during font scaling and mirrored into the copy.
    public override var baselineAdjustment: UIBaselineAdjustment {
        didSet {
            shimmerOverlayLabel.baselineAdjustment = baselineAdjustment
        }
    }

    /// Whether native font-size fitting is also applied to the highlight copy.
    public override var adjustsFontSizeToFitWidth: Bool {
        didSet {
            shimmerOverlayLabel.adjustsFontSizeToFitWidth =
                adjustsFontSizeToFitWidth
        }
    }

    /// Lowest native font scale mirrored into the private highlight copy.
    public override var minimumScaleFactor: CGFloat {
        didSet {
            shimmerOverlayLabel.minimumScaleFactor = minimumScaleFactor
        }
    }

    /// Whether native truncation tightening is mirrored into the highlight copy.
    public override var allowsDefaultTighteningForTruncation: Bool {
        didSet {
            shimmerOverlayLabel.allowsDefaultTighteningForTruncation =
                allowsDefaultTighteningForTruncation
        }
    }

    /// Preferred multiline width, in points, mirrored into the highlight copy.
    public override var preferredMaxLayoutWidth: CGFloat {
        didSet {
            shimmerOverlayLabel.preferredMaxLayoutWidth = preferredMaxLayoutWidth
        }
    }

    /// Whether preferred text-style fonts update for Dynamic Type in both labels.
    public override var adjustsFontForContentSizeCategory: Bool {
        didSet {
            shimmerOverlayLabel.adjustsFontForContentSizeCategory =
                adjustsFontForContentSizeCategory
        }
    }

    /// Aligns the private copy and rebuilds geometry only after bounds change.
    public override func layoutSubviews() {
        super.layoutSubviews()
        shimmerOverlayLabel.frame = bounds
        reconcileAnimation()
    }

    /// Starts or removes animation when the label enters or leaves a window.
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        reconcileAnimation()
    }

    /// Re-resolves semantic direction after interface traits change.
    ///
    /// - Parameter previousTraitCollection: Traits active before the change.
    public override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)
        reconcileAnimation()
    }

    /// Installs the noninteractive copy and observes changes Core Animation cannot infer.
    private func setUp() {
        isAccessibilityElement = true
        shimmerOverlayLabel.isHidden = true
        shimmerOverlayLabel.isAccessibilityElement = false
        shimmerOverlayLabel.isUserInteractionEnabled = false
        addSubview(shimmerOverlayLabel)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnvironmentChange),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnvironmentChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )

        synchronizeOverlayContent()
    }

    /// Copies text drawing state without modifying the receiver's rich content.
    private func synchronizeOverlayContent() {
        let resolved = configuration.resolved
        let highlight = highlightColor.withAlphaComponent(resolved.intensity)
        shimmerOverlayLabel.textStyle = highlightedStyle(
            textStyle,
            color: highlight
        )

        if let attributedText {
            let copy = NSMutableAttributedString(attributedString: attributedText)
            if copy.length > 0 {
                copy.addAttribute(
                    .foregroundColor,
                    value: highlight,
                    range: NSRange(location: 0, length: copy.length)
                )
            }
            shimmerOverlayLabel.attributedText = copy
        } else {
            shimmerOverlayLabel.attributedText = nil
            shimmerOverlayLabel.text = text
            shimmerOverlayLabel.textColor = highlight
        }

        shimmerOverlayLabel.font = font
        shimmerOverlayLabel.numberOfLines = numberOfLines
        shimmerOverlayLabel.lineBreakMode = lineBreakMode
        shimmerOverlayLabel.textAlignment = textAlignment
        shimmerOverlayLabel.baselineAdjustment = baselineAdjustment
        shimmerOverlayLabel.adjustsFontSizeToFitWidth = adjustsFontSizeToFitWidth
        shimmerOverlayLabel.minimumScaleFactor = minimumScaleFactor
        shimmerOverlayLabel.allowsDefaultTighteningForTruncation =
            allowsDefaultTighteningForTruncation
        shimmerOverlayLabel.preferredMaxLayoutWidth = preferredMaxLayoutWidth
        shimmerOverlayLabel.adjustsFontForContentSizeCategory =
            adjustsFontForContentSizeCategory
    }

    private func highlightedStyle(
        _ style: ITextUIKitStyle?,
        color: UIColor
    ) -> ITextUIKitStyle? {
        guard let style else { return nil }
        return ITextUIKitStyle(
            fill: style.fill.map { _ in .solid(color) },
            stroke: style.stroke.map {
                ITextStroke(paint: .solid(color), width: $0.width)
            }
        )
    }

    /// Reconciles requested state with content, layout, lifecycle, and accessibility.
    private func reconcileAnimation() {
        let resolved = configuration.resolved
        let shouldAnimate = ITextShimmerActivationState.shouldAnimate(
            isRequested: isShimmering,
            hasContent: hasTextContent,
            hasBounds: !bounds.isEmpty,
            isInWindow: window != nil,
            reduceMotion: UIAccessibility.isReduceMotionEnabled,
            intensity: resolved.intensity
        )

        guard shouldAnimate else {
            stopAnimation()
            return
        }

        let direction = resolved.direction.resolved(
            isRightToLeft: effectiveUserInterfaceLayoutDirection == .rightToLeft
        )
        let mask = shimmerOverlayLabel.layer.mask
        let hasAnimation = mask?.animation(forKey: animationKey) != nil

        // Retain the existing animation when every input is unchanged. This
        // keeps repeated layout and state assignment idempotent.
        guard mask == nil ||
                !hasAnimation ||
                lastAnimatedBounds != bounds ||
                lastTravelDirection != direction else {
            return
        }

        startAnimation(configuration: resolved, direction: direction)
    }

    /// Replaces the current mask with one infinite, linear Core Animation sweep.
    private func startAnimation(
        configuration: ITextShimmerResolvedConfiguration,
        direction: ITextShimmerTravelDirection
    ) {
        stopAnimation()
        synchronizeOverlayContent()

        let geometry = ITextShimmerGeometry(
            containerWidth: bounds.width,
            bandFraction: configuration.bandWidth
        )
        let start = geometry.center(at: 0, direction: direction)
        let end = geometry.center(at: 1, direction: direction)

        let gradient = CAGradientLayer()
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.35).cgColor,
            UIColor.black.cgColor,
            UIColor.black.withAlphaComponent(0.35).cgColor,
            UIColor.clear.cgColor
        ]
        gradient.locations = [0, 0.25, 0.5, 0.75, 1]

        // The model layer is placed at the final position while the explicit
        // animation supplies presentation frames. Disabled actions prevent an
        // unrelated implicit transition during creation or restart.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.bounds = CGRect(
            x: 0,
            y: 0,
            width: geometry.bandWidth,
            height: bounds.height
        )
        gradient.position = CGPoint(x: end, y: bounds.midY)
        shimmerOverlayLabel.layer.mask = gradient
        CATransaction.commit()

        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = start
        animation.toValue = end
        animation.duration = configuration.duration
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        gradient.add(animation, forKey: animationKey)

        shimmerOverlayLabel.isHidden = false
        lastAnimatedBounds = bounds
        lastTravelDirection = direction
    }

    /// Removes all renderer-owned state and exposes only stable base text.
    private func stopAnimation() {
        shimmerOverlayLabel.layer.mask?.removeAnimation(forKey: animationKey)
        shimmerOverlayLabel.layer.mask = nil
        shimmerOverlayLabel.isHidden = true
        lastAnimatedBounds = .null
        lastTravelDirection = nil
    }

    /// Restarts an active request after a meaningful configuration change.
    private func rebuildAnimationIfNeeded() {
        guard isShimmering else { return }
        stopAnimation()
        reconcileAnimation()
    }

    /// Whether the current plain or attributed value contains any characters.
    private var hasTextContent: Bool {
        if let attributedText {
            return attributedText.length > 0
        }
        return !(text?.isEmpty ?? true)
    }

    /// Reconciles a restored foreground or a changed Reduce Motion preference.
    @objc private func handleEnvironmentChange() {
        reconcileAnimation()
    }
}
