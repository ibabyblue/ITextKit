import UIKit
import XCTest
@testable import ITextKit

@MainActor
final class ITextStyledTextVisualTests: XCTestCase {
    func testStrokeWidthsExpandIntrinsicGeometryByExactOutwardPoints() {
        let samples = [
            "Outline", "渐变描边", "العربية", "A\u{0301}", "office", "👨‍👩‍👧‍👦",
        ]
        let widths: [CGFloat] = [0, 0.5, 1, 2, 3]

        for sample in samples {
            let label = ITextStyledLabel()
            label.text = sample
            label.font = .systemFont(ofSize: 28, weight: .bold)
            label.textStyle = .init(fill: .solid(.systemPink))
            let base = label.intrinsicContentSize

            for width in widths {
                label.textStyle = .init(
                    fill: .linearGradient(.init(colors: [.systemPink, .systemOrange])),
                    stroke: .init(
                        paint: .linearGradient(.init(colors: [.white, .black])),
                        width: width
                    )
                )
                let size = label.intrinsicContentSize
                XCTAssertEqual(size.width, base.width + 2 * width, accuracy: 1 / 3)
                XCTAssertEqual(size.height, base.height + 2 * width, accuracy: 1 / 3)
            }
        }
    }

    func testMultilineGradientAndRTLRenderFiniteForegroundBounds() {
        for direction in [
            UISemanticContentAttribute.forceLeftToRight,
            .forceRightToLeft,
        ] {
            let label = ITextStyledLabel(
                frame: CGRect(x: 0, y: 0, width: 180, height: 120)
            )
            label.text = "First gradient line\n第二行 العربية"
            label.font = .systemFont(ofSize: 22)
            label.numberOfLines = 0
            label.semanticContentAttribute = direction
            label.textStyle = .init(
                fill: .linearGradient(.init(colors: [.red, .blue])),
                stroke: .init(
                    paint: .linearGradient(.init(colors: [.white, .black])),
                    width: 2
                )
            )
            label.layoutIfNeeded()

            XCTAssertGreaterThan(label.intrinsicContentSize.width, 0)
            XCTAssertGreaterThan(label.intrinsicContentSize.height, 0)
            XCTAssertGreaterThan(label._layoutGeneration, 0)
        }
    }
}
