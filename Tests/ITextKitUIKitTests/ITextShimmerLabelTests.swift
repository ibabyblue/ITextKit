import UIKit
import XCTest
@testable import ITextKit

@MainActor
final class ITextShimmerLabelTests: XCTestCase {
    func testPublicDefaultsAndPlainTextSynchronization() throws {
        let label = ITextShimmerLabel()
        label.text = "Working…"
        label.font = .preferredFont(forTextStyle: .headline)
        label.numberOfLines = 0
        label.textAlignment = .center

        let overlay = try XCTUnwrap(label.subviews.compactMap { $0 as? UILabel }.first)
        XCTAssertEqual(label.configuration, .default)
        XCTAssertEqual(label.highlightColor, .label)
        XCTAssertFalse(label.isShimmering)
        XCTAssertEqual(overlay.text, label.text)
        XCTAssertEqual(overlay.font, label.font)
        XCTAssertEqual(overlay.numberOfLines, 0)
        XCTAssertEqual(overlay.textAlignment, .center)
        XCTAssertFalse(overlay.isAccessibilityElement)
        XCTAssertFalse(overlay.isUserInteractionEnabled)
    }

    func testAttributedTextCopyPreservesInputAndOverridesOnlyOverlayForeground() throws {
        let source = NSAttributedString(
            string: "Working…",
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.systemPink,
                .kern: 1.5
            ]
        )
        let label = ITextShimmerLabel()
        label.configuration = .init(intensity: 1)
        label.highlightColor = .systemYellow
        label.attributedText = source

        let overlay = try XCTUnwrap(label.subviews.compactMap { $0 as? UILabel }.first)
        let overlayText = try XCTUnwrap(overlay.attributedText)
        XCTAssertEqual(
            source.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor,
            .systemPink
        )
        XCTAssertEqual(
            overlayText.attribute(.kern, at: 0, effectiveRange: nil) as? NSNumber,
            1.5
        )
        let traits = UITraitCollection(userInterfaceStyle: .light)
        let color = try XCTUnwrap(
            overlayText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        )
        XCTAssertEqual(
            color.resolvedColor(with: traits).cgColor,
            UIColor.systemYellow.resolvedColor(with: traits).cgColor
        )
    }

    func testDrawingPropertiesAndIntrinsicSizeStaySynchronized() throws {
        let label = ITextShimmerLabel()
        label.text = "A multiline shimmer label"
        label.numberOfLines = 0
        label.lineBreakMode = .byTruncatingMiddle
        label.baselineAdjustment = .alignCenters
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.allowsDefaultTighteningForTruncation = true
        label.preferredMaxLayoutWidth = 240
        label.adjustsFontForContentSizeCategory = true

        let overlay = try XCTUnwrap(label.subviews.compactMap { $0 as? UILabel }.first)
        XCTAssertEqual(overlay.numberOfLines, label.numberOfLines)
        XCTAssertEqual(overlay.lineBreakMode, label.lineBreakMode)
        XCTAssertEqual(overlay.baselineAdjustment, label.baselineAdjustment)
        XCTAssertEqual(overlay.adjustsFontSizeToFitWidth, label.adjustsFontSizeToFitWidth)
        XCTAssertEqual(overlay.minimumScaleFactor, label.minimumScaleFactor)
        XCTAssertEqual(
            overlay.allowsDefaultTighteningForTruncation,
            label.allowsDefaultTighteningForTruncation
        )
        XCTAssertEqual(overlay.preferredMaxLayoutWidth, label.preferredMaxLayoutWidth)
        XCTAssertEqual(
            overlay.adjustsFontForContentSizeCategory,
            label.adjustsFontForContentSizeCategory
        )
        XCTAssertEqual(
            label.intrinsicContentSize,
            UILabel.copyingLayout(from: label).intrinsicContentSize
        )
    }

    func testActivationAddsExactlyOneGradientMaskAndAnimation() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        let controller = UIViewController()
        window.rootViewController = controller
        let label = ITextShimmerLabel(frame: CGRect(x: 20, y: 20, width: 200, height: 40))
        label.text = "Working…"
        controller.view.addSubview(label)
        window.makeKeyAndVisible()

        label.isShimmering = true
        label.layoutIfNeeded()
        label.isShimmering = true
        label.layoutIfNeeded()

        let overlay = try XCTUnwrap(label.subviews.compactMap { $0 as? UILabel }.first)
        let gradient = try XCTUnwrap(overlay.layer.mask as? CAGradientLayer)
        XCTAssertEqual(gradient.animationKeys(), ["ITextKit.shimmer.position"])
    }

    func testBoundsAndConfigurationChangesReplaceAnimation() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 200))
        let controller = UIViewController()
        window.rootViewController = controller
        let label = ITextShimmerLabel(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        label.text = "Working…"
        controller.view.addSubview(label)
        window.makeKeyAndVisible()
        label.isShimmering = true
        label.layoutIfNeeded()

        let overlay = try XCTUnwrap(label.subviews.compactMap { $0 as? UILabel }.first)
        let first = try XCTUnwrap(
            ((overlay.layer.mask?.animation(
                forKey: "ITextKit.shimmer.position"
            ) as? CABasicAnimation)?.toValue as? NSNumber)?.doubleValue
        )

        label.frame.size.width = 200
        label.configuration = .init(duration: 2.25)
        label.layoutIfNeeded()

        let animation = try XCTUnwrap(
            overlay.layer.mask?.animation(
                forKey: "ITextKit.shimmer.position"
            ) as? CABasicAnimation
        )
        let second = try XCTUnwrap((animation.toValue as? NSNumber)?.doubleValue)
        XCTAssertGreaterThan(second, first)
        XCTAssertEqual(animation.duration, 2.25)
        XCTAssertEqual(overlay.layer.mask?.animationKeys(), ["ITextKit.shimmer.position"])
    }

    func testDeactivationWindowRemovalAndMissingContentRemoveAnimation() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        let controller = UIViewController()
        window.rootViewController = controller
        let label = ITextShimmerLabel(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        controller.view.addSubview(label)
        window.makeKeyAndVisible()
        label.isShimmering = true
        label.layoutIfNeeded()

        let overlay = try XCTUnwrap(label.subviews.compactMap { $0 as? UILabel }.first)
        XCTAssertNil(overlay.layer.mask)

        label.text = "Working…"
        label.layoutIfNeeded()
        XCTAssertNotNil(overlay.layer.mask)

        label.isShimmering = false
        XCTAssertNil(overlay.layer.mask)
        XCTAssertTrue(overlay.isHidden)

        label.isShimmering = true
        label.layoutIfNeeded()
        label.removeFromSuperview()
        XCTAssertNil(overlay.layer.mask)
    }
}

private extension UILabel {
    static func copyingLayout(from source: UILabel) -> UILabel {
        let copy = UILabel()
        if let attributedText = source.attributedText {
            copy.attributedText = attributedText
        } else {
            copy.text = source.text
        }
        copy.font = source.font
        copy.numberOfLines = source.numberOfLines
        copy.lineBreakMode = source.lineBreakMode
        copy.preferredMaxLayoutWidth = source.preferredMaxLayoutWidth
        return copy
    }
}
