import SwiftUI
import UIKit

/// SwiftUI styled text backed by the same vector renderer as
/// ``ITextStyledLabel``.
///
/// The explicit `UIFont`/`NSAttributedString` boundary is intentional: it is
/// available from iOS 15 and does not pretend to extract glyphs from an opaque
/// native `Text` or SwiftUI `Font` value.
@MainActor
public struct ITextStyledText: View {
    private let attributedText: NSAttributedString
    private let defaultFont: UIFont
    private let style: ITextSwiftUIStyle
    private let adjustsFontForContentSizeCategory: Bool
    private let gradientReferenceAttributedText: NSAttributedString?

    @Environment(\.lineLimit) private var lineLimit
    @Environment(\.multilineTextAlignment) private var multilineTextAlignment
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale

    /// Creates styled plain text using an explicit UIKit font.
    public init(
        _ text: String,
        font: UIFont = .preferredFont(forTextStyle: .body),
        style: ITextSwiftUIStyle,
        adjustsFontForContentSizeCategory: Bool = true
    ) {
        self.init(
            attributedText: NSAttributedString(string: text),
            defaultFont: font,
            style: style,
            adjustsFontForContentSizeCategory: adjustsFontForContentSizeCategory,
            gradientReferenceAttributedText: nil
        )
    }

    /// Creates styled rich text while preserving every caller-owned attribute.
    public init(
        attributedText: NSAttributedString,
        defaultFont: UIFont = .preferredFont(forTextStyle: .body),
        style: ITextSwiftUIStyle,
        adjustsFontForContentSizeCategory: Bool = true
    ) {
        self.init(
            attributedText: attributedText,
            defaultFont: defaultFont,
            style: style,
            adjustsFontForContentSizeCategory: adjustsFontForContentSizeCategory,
            gradientReferenceAttributedText: nil
        )
    }

    init(
        attributedText: NSAttributedString,
        defaultFont: UIFont,
        style: ITextSwiftUIStyle,
        adjustsFontForContentSizeCategory: Bool,
        gradientReferenceAttributedText: NSAttributedString?
    ) {
        self.attributedText = NSAttributedString(
            attributedString: attributedText
        )
        self.defaultFont = defaultFont
        self.style = style
        self.adjustsFontForContentSizeCategory =
            adjustsFontForContentSizeCategory
        self.gradientReferenceAttributedText = gradientReferenceAttributedText
            .map(NSAttributedString.init(attributedString:))
    }

    public var body: some View {
        _ITextStyledLabelRepresentable(
            attributedText: attributedText,
            gradientReferenceAttributedText: gradientReferenceAttributedText,
            defaultFont: resolvedDefaultFont,
            style: Self.resolve(style),
            numberOfLines: lineLimit ?? 0,
            alignment: Self.resolve(multilineTextAlignment),
            layoutDirection: layoutDirection,
            displayScale: displayScale
        )
        .accessibilityLabel(Text(attributedText.string))
    }

    private var resolvedDefaultFont: UIFont {
        guard adjustsFontForContentSizeCategory else { return defaultFont }
        let traits = UITraitCollection(
            preferredContentSizeCategory: Self.contentSizeCategory(
                for: dynamicTypeSize
            )
        )
        return UIFontMetrics.default.scaledFont(
            for: defaultFont,
            compatibleWith: traits
        )
    }

    private static func resolve(
        _ style: ITextSwiftUIStyle
    ) -> ITextUIKitStyle {
        ITextUIKitStyle(
            fill: style.fill.map(resolve),
            stroke: style.stroke.map {
                ITextStroke(
                    paint: resolve($0.paint),
                    width: $0.width
                )
            }
        )
    }

    private static func resolve(
        _ paint: ITextPaint<Color>
    ) -> ITextPaint<UIColor> {
        switch paint {
        case .solid(let color):
            return .solid(UIColor(color))
        case .linearGradient(let gradient):
            return .linearGradient(ITextLinearGradient(
                stops: gradient.stops.map {
                    ITextGradientStop(
                        color: UIColor($0.color),
                        location: $0.location
                    )
                },
                startPoint: gradient.startPoint,
                endPoint: gradient.endPoint
            ))
        }
    }

    private static func resolve(
        _ alignment: TextAlignment
    ) -> NSTextAlignment {
        switch alignment {
        case .center:
            return .center
        case .trailing:
            return .right
        default:
            return .natural
        }
    }

    private static func contentSizeCategory(
        for size: DynamicTypeSize
    ) -> UIContentSizeCategory {
        switch size {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }
}

@MainActor
private struct _ITextStyledLabelRepresentable: UIViewRepresentable {
    let attributedText: NSAttributedString
    let gradientReferenceAttributedText: NSAttributedString?
    let defaultFont: UIFont
    let style: ITextUIKitStyle
    let numberOfLines: Int
    let alignment: NSTextAlignment
    let layoutDirection: LayoutDirection
    let displayScale: CGFloat

    func makeUIView(context: Context) -> ITextStyledLabel {
        let label = ITextStyledLabel()
        label.backgroundColor = .clear
        label.isAccessibilityElement = true
        label.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        update(label)
        return label
    }

    func updateUIView(_ label: ITextStyledLabel, context: Context) {
        update(label)
        let actualWidth = label.bounds.width
        if actualWidth > 0,
           label.preferredMaxLayoutWidth != actualWidth {
            label.preferredMaxLayoutWidth = actualWidth
        }
    }

    @available(iOS 16.0, *)
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: ITextStyledLabel,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? CGFloat.greatestFiniteMagnitude
        let height = proposal.height ?? CGFloat.greatestFiniteMagnitude
        if proposal.width != nil,
           uiView.preferredMaxLayoutWidth != width {
            uiView.preferredMaxLayoutWidth = width
        }
        return uiView.sizeThatFits(CGSize(width: width, height: height))
    }

    private func update(_ label: ITextStyledLabel) {
        if label.attributedText?.isEqual(to: attributedText) != true {
            label.attributedText = attributedText
        }
        if !label.font.isEqual(defaultFont) {
            label.font = defaultFont
        }
        if label.textStyle != style {
            label.textStyle = style
        }
        if label.numberOfLines != numberOfLines {
            label.numberOfLines = numberOfLines
        }
        if label.textAlignment != alignment {
            label.textAlignment = alignment
        }
        let lineBreakMode: NSLineBreakMode = numberOfLines == 1
            ? .byTruncatingTail
            : .byWordWrapping
        if label.lineBreakMode != lineBreakMode {
            label.lineBreakMode = lineBreakMode
        }
        let semantic: UISemanticContentAttribute = layoutDirection == .rightToLeft
            ? .forceRightToLeft
            : .forceLeftToRight
        if label.semanticContentAttribute != semantic {
            label.semanticContentAttribute = semantic
        }
        let referenceIsEqual: Bool
        if let current = label._gradientReferenceAttributedText,
           let proposed = gradientReferenceAttributedText {
            referenceIsEqual = current.isEqual(to: proposed)
        } else {
            referenceIsEqual = label._gradientReferenceAttributedText == nil
                && gradientReferenceAttributedText == nil
        }
        if !referenceIsEqual {
            label._gradientReferenceAttributedText =
                gradientReferenceAttributedText
        }
        label.accessibilityLabel = attributedText.string
        label.layer.contentsScale = displayScale
    }
}
