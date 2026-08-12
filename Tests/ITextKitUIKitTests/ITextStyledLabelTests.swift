import UIKit
import XCTest
@testable import ITextKit

@MainActor
final class ITextStyledLabelTests: XCTestCase {
    func testNilStyleMatchesNativeIntrinsicSize() {
        let native = UILabel()
        native.text = "Native path"
        native.font = .systemFont(ofSize: 24, weight: .bold)

        let styled = ITextStyledLabel()
        styled.text = native.text
        styled.font = native.font
        styled.textStyle = nil

        XCTAssertEqual(styled.intrinsicContentSize, native.intrinsicContentSize)
    }

    func testTwoPointStrokeAddsFourPointsToUnconstrainedSize() {
        let label = ITextStyledLabel()
        label.text = "Outline"
        label.font = .systemFont(ofSize: 24)
        let base = label.intrinsicContentSize

        label.textStyle = .init(
            stroke: .init(paint: .solid(.black), width: 2)
        )

        XCTAssertEqual(label.intrinsicContentSize.width, base.width + 4, accuracy: 1)
        XCTAssertEqual(label.intrinsicContentSize.height, base.height + 4, accuracy: 1)
    }

    func testMutableAttributedInputIsNotMutated() {
        let source = NSMutableAttributedString(
            string: "Rich",
            attributes: [.foregroundColor: UIColor.red]
        )
        let label = ITextStyledLabel()
        label.attributedText = source
        label.textStyle = .init(fill: .solid(.blue))
        label.sizeToFit()
        label.layoutIfNeeded()

        XCTAssertEqual(
            source.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor,
            .red
        )
    }

    func testMultilinePreferredWidthAndSizeThatFitsStayConstrained() {
        let label = ITextStyledLabel()
        label.text = "A styled label that wraps over several lines"
        label.font = .systemFont(ofSize: 20)
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = 120
        label.textStyle = .init(
            fill: .solid(.systemBlue),
            stroke: .init(paint: .solid(.black), width: 1)
        )

        let intrinsic = label.intrinsicContentSize
        let fitting = label.sizeThatFits(CGSize(width: 120, height: 500))

        XCTAssertLessThanOrEqual(intrinsic.width, 120)
        XCTAssertGreaterThan(intrinsic.height, label.font.lineHeight)
        XCTAssertLessThanOrEqual(fitting.width, 120)
    }

    func testStyleMutationInvalidatesLayoutGeneration() {
        let label = ITextStyledLabel(frame: CGRect(x: 0, y: 0, width: 180, height: 60))
        label.text = "Mutation"
        label.textStyle = .init(fill: .solid(.red))
        label.layoutIfNeeded()
        let first = label._layoutGeneration

        label.textStyle = .init(
            fill: .solid(.blue),
            stroke: .init(paint: .solid(.black), width: 2)
        )
        label.layoutIfNeeded()

        XCTAssertGreaterThan(label._layoutGeneration, first)
    }

    func testFillOnlyMutationReusesLayoutGeneration() {
        let label = ITextStyledLabel(
            frame: CGRect(x: 0, y: 0, width: 180, height: 60)
        )
        label.text = "Paint only"
        label.textStyle = .init(fill: .solid(.red))
        label.layoutIfNeeded()
        let first = label._layoutGeneration

        label.textStyle = .init(fill: .solid(.blue))
        label.layoutIfNeeded()

        XCTAssertEqual(label._layoutGeneration, first)
    }

    func testEmptyStyledTextHasZeroIntrinsicSize() {
        let label = ITextStyledLabel()
        label.textStyle = .init(fill: .solid(.red))

        XCTAssertEqual(label.intrinsicContentSize, .zero)
    }
}
