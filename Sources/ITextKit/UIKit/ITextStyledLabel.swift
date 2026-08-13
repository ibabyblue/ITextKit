import UIKit

/// A UILabel-compatible vector text renderer supporting solid or linear-gradient
/// fill and an exact outward outline measured in points.
///
/// With a `nil` style, every layout and drawing operation follows UILabel's
/// native path. Styled text keeps this label as its only accessibility, layout,
/// and interaction owner; rendering is performed directly by a private layer.
@MainActor
public class ITextStyledLabel: UILabel {
    /// Optional view-wide fill and outline styling.
    ///
    /// A stroke width of `w` extends exactly `w` points outside the glyph. Its
    /// centered `2w` vector stroke is rendered first, then covered by the fill.
    public var textStyle: ITextUIKitStyle? {
        didSet {
            guard textStyle != oldValue else { return }
            guard oldValue != nil, textStyle != nil else {
                invalidateStyledLayout()
                return
            }
            let oldWidth = resolvedStrokeWidth(oldValue)
            let newWidth = resolvedStrokeWidth(textStyle)
            if oldWidth != newWidth {
                invalidateStyledLayout()
            } else {
                invalidateStyledPaint()
            }
        }
    }

    /// Optional full-text reference used only for stable gradient coordinates.
    /// Visible content, size, baseline, and accessibility remain unchanged.
    var _gradientReferenceAttributedText: NSAttributedString? {
        didSet {
            guard !Self.attributedStringsAreEqual(
                _gradientReferenceAttributedText,
                oldValue
            ) else { return }
            invalidateStyledPaint()
        }
    }

    var _layoutGeneration: UInt64 {
        currentLayout?.layoutGeneration ?? 0
    }

    var _drawingGeneration: UInt64 {
        drawingLayer.drawingGeneration
    }

    private let layoutEngine = _ITextLayoutEngine()
    private let drawingLayer = _ITextDrawingLayer()
    private var currentLayout: _ITextLayoutResult?
    private var currentLayoutSize: CGSize = .init(width: -1, height: -1)
    private var layoutIsDirty = true
    private var paintIsDirty = true

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUpStyledLabel()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpStyledLabel()
    }

    public override var text: String? {
        didSet {
            guard text != oldValue else { return }
            invalidateStyledLayout()
        }
    }

    public override var attributedText: NSAttributedString? {
        didSet {
            guard !Self.attributedStringsAreEqual(attributedText, oldValue) else {
                return
            }
            invalidateStyledLayout()
        }
    }

    public override var font: UIFont! {
        didSet {
            guard font != oldValue else { return }
            invalidateStyledLayout()
        }
    }

    public override var textColor: UIColor! {
        didSet {
            guard textColor != oldValue else { return }
            invalidateStyledLayout()
        }
    }

    public override var numberOfLines: Int {
        didSet {
            guard numberOfLines != oldValue else { return }
            invalidateStyledLayout()
        }
    }

    public override var lineBreakMode: NSLineBreakMode {
        didSet {
            guard lineBreakMode != oldValue else { return }
            invalidateStyledLayout()
        }
    }

    public override var textAlignment: NSTextAlignment {
        didSet {
            guard textAlignment != oldValue else { return }
            invalidateStyledLayout()
        }
    }

    public override var baselineAdjustment: UIBaselineAdjustment {
        didSet {
            guard baselineAdjustment != oldValue else { return }
            invalidateStyledLayout()
        }
    }

    public override var adjustsFontSizeToFitWidth: Bool {
        didSet {
            guard adjustsFontSizeToFitWidth != oldValue else { return }
            invalidateStyledLayout()
        }
    }

    public override var minimumScaleFactor: CGFloat {
        didSet {
            guard minimumScaleFactor != oldValue else { return }
            invalidateStyledLayout()
        }
    }

    public override var allowsDefaultTighteningForTruncation: Bool {
        didSet {
            guard allowsDefaultTighteningForTruncation != oldValue else { return }
            invalidateStyledLayout()
        }
    }

    public override var preferredMaxLayoutWidth: CGFloat {
        didSet {
            guard preferredMaxLayoutWidth != oldValue else { return }
            invalidateStyledLayout()
        }
    }

    public override var shadowColor: UIColor? {
        didSet {
            guard shadowColor != oldValue else { return }
            invalidateStyledPaint()
        }
    }

    public override var shadowOffset: CGSize {
        didSet {
            guard shadowOffset != oldValue else { return }
            invalidateStyledPaint()
        }
    }

    public override var semanticContentAttribute: UISemanticContentAttribute {
        didSet {
            guard semanticContentAttribute != oldValue else { return }
            invalidateStyledLayout()
        }
    }

    public override var intrinsicContentSize: CGSize {
        guard textStyle != nil else { return super.intrinsicContentSize }
        guard hasStyledContent else { return .zero }
        let width = preferredMaxLayoutWidth > 0
            ? preferredMaxLayoutWidth
            : CGFloat.greatestFiniteMagnitude
        return makeLayout(constrainedTo: CGSize(
            width: width,
            height: .greatestFiniteMagnitude
        )).size
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard textStyle != nil else { return super.sizeThatFits(size) }
        guard hasStyledContent else { return .zero }
        return makeLayout(constrainedTo: size).size
    }

    public override func textRect(
        forBounds bounds: CGRect,
        limitedToNumberOfLines numberOfLines: Int
    ) -> CGRect {
        guard textStyle != nil else {
            return super.textRect(
                forBounds: bounds,
                limitedToNumberOfLines: numberOfLines
            )
        }
        guard hasStyledContent else {
            return CGRect(origin: bounds.origin, size: .zero)
        }
        let result = makeLayout(
            constrainedTo: bounds.size,
            numberOfLines: numberOfLines
        )
        return CGRect(
            x: bounds.minX,
            y: bounds.midY - result.size.height / 2,
            width: result.size.width,
            height: result.size.height
        )
    }

    public override func drawText(in rect: CGRect) {
        guard textStyle != nil else {
            super.drawText(in: rect)
            return
        }
        // Styled glyphs are drawn by the direct vector sublayer.
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard textStyle != nil, hasStyledContent else {
            drawingLayer.isHidden = true
            drawingLayer.plan = nil
            currentLayout = nil
            return
        }
        drawingLayer.isHidden = false
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        drawingLayer.frame = bounds
        drawingLayer.contentsScale = window?.screen.scale
            ?? traitCollection.displayScale
        CATransaction.commit()

        if currentLayoutSize != bounds.size {
            layoutIsDirty = true
        }
        if layoutIsDirty {
            currentLayout = makeLayout(constrainedTo: bounds.size)
            currentLayoutSize = bounds.size
            layoutIsDirty = false
            paintIsDirty = true
        }
        if paintIsDirty {
            rebuildDrawingPlan()
            paintIsDirty = false
        }
    }

    public override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard let previousTraitCollection else {
            invalidateStyledPaint()
            return
        }
        if traitCollection.preferredContentSizeCategory
            != previousTraitCollection.preferredContentSizeCategory {
            invalidateStyledLayout()
        } else if traitCollection.hasDifferentColorAppearance(
            comparedTo: previousTraitCollection
        ) {
            invalidateStyledPaint()
        }
    }

    private var hasStyledContent: Bool {
        if let attributedText {
            return attributedText.length > 0
        }
        return !(text ?? "").isEmpty
    }

    private func setUpStyledLabel() {
        drawingLayer.isHidden = true
        layer.addSublayer(drawingLayer)
    }

    private func invalidateStyledLayout() {
        guard textStyle != nil else {
            drawingLayer.isHidden = true
            drawingLayer.plan = nil
            currentLayout = nil
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
            return
        }
        layoutIsDirty = true
        paintIsDirty = true
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        setNeedsDisplay()
    }

    private func invalidateStyledPaint() {
        guard textStyle != nil else { return }
        paintIsDirty = true
        setNeedsLayout()
        drawingLayer.setNeedsDisplay()
    }

    private func makeLayout(
        constrainedTo size: CGSize,
        numberOfLines limitedLines: Int? = nil,
        attributedText overrideText: NSAttributedString? = nil
    ) -> _ITextLayoutResult {
        let style = textStyle ?? .init()
        let direction = effectiveUserInterfaceLayoutDirection
        let stroke = style._resolved(
            isRightToLeft: direction == .rightToLeft
        ).stroke?.outwardWidth ?? 0
        return layoutEngine.layout(_ITextLayoutRequest(
            attributedText: overrideText ?? styledAttributedText,
            defaultFont: font ?? .systemFont(ofSize: UIFont.systemFontSize),
            defaultColor: textColor ?? .label,
            constrainedSize: size,
            numberOfLines: limitedLines ?? numberOfLines,
            lineBreakMode: lineBreakMode,
            alignment: textAlignment,
            baselineAdjustment: baselineAdjustment,
            adjustsFontSizeToFitWidth: adjustsFontSizeToFitWidth,
            minimumScaleFactor: minimumScaleFactor,
            allowsTightening: allowsDefaultTighteningForTruncation,
            layoutDirection: direction,
            displayScale: window?.screen.scale ?? traitCollection.displayScale,
            outwardStrokeWidth: stroke
        ))
    }

    private var styledAttributedText: NSAttributedString {
        if let attributedText {
            return NSAttributedString(attributedString: attributedText)
        }
        return NSAttributedString(string: text ?? "")
    }

    private func rebuildDrawingPlan() {
        guard let currentLayout, let textStyle else {
            drawingLayer.plan = nil
            return
        }
        var gradientBounds = currentLayout.inkBounds
        if let reference = _gradientReferenceAttributedText,
           reference.length > 0 {
            gradientBounds = makeLayout(
                constrainedTo: bounds.size,
                attributedText: reference
            ).inkBounds
        }
        let verticalOffset = max((bounds.height - currentLayout.size.height) / 2, 0)
        drawingLayer.plan = _ITextDrawingPlan(
            layout: currentLayout,
            style: textStyle,
            gradientBounds: gradientBounds,
            traitCollection: traitCollection,
            layoutDirection: effectiveUserInterfaceLayoutDirection,
            shadowColor: shadowColor,
            shadowOffset: shadowOffset,
            drawingOffset: CGPoint(x: 0, y: verticalOffset)
        )
    }

    private func resolvedStrokeWidth(_ style: ITextUIKitStyle?) -> CGFloat {
        style?._resolved(
            isRightToLeft: effectiveUserInterfaceLayoutDirection == .rightToLeft
        ).stroke?.outwardWidth ?? 0
    }

    private static func attributedStringsAreEqual(
        _ lhs: NSAttributedString?,
        _ rhs: NSAttributedString?
    ) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return lhs.isEqual(to: rhs)
        default:
            return false
        }
    }
}
