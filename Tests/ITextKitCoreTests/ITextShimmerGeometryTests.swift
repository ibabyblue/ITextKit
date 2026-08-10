import CoreGraphics
import XCTest
@testable import ITextKit

final class ITextShimmerGeometryTests: XCTestCase {
    func testSemanticDirectionResolvesAgainstLayoutDirection() {
        XCTAssertEqual(
            ITextShimmerDirection.leadingToTrailing.resolved(isRightToLeft: false),
            .leftToRight
        )
        XCTAssertEqual(
            ITextShimmerDirection.leadingToTrailing.resolved(isRightToLeft: true),
            .rightToLeft
        )
        XCTAssertEqual(
            ITextShimmerDirection.trailingToLeading.resolved(isRightToLeft: false),
            .rightToLeft
        )
        XCTAssertEqual(
            ITextShimmerDirection.trailingToLeading.resolved(isRightToLeft: true),
            .leftToRight
        )
    }

    func testBandStartsAndEndsFullyOutsideBounds() {
        let geometry = ITextShimmerGeometry(
            containerWidth: 200,
            bandFraction: 0.25
        )

        XCTAssertEqual(geometry.bandWidth, 50)
        XCTAssertEqual(geometry.leftOffscreenCenter, -25)
        XCTAssertEqual(geometry.rightOffscreenCenter, 225)
    }

    func testProgressClampsAndResolvesBothDirections() {
        let geometry = ITextShimmerGeometry(
            containerWidth: 200,
            bandFraction: 0.25
        )

        XCTAssertEqual(geometry.center(at: -1, direction: .leftToRight), -25)
        XCTAssertEqual(geometry.center(at: 0.5, direction: .leftToRight), 100)
        XCTAssertEqual(geometry.center(at: 2, direction: .leftToRight), 225)
        XCTAssertEqual(geometry.center(at: 0, direction: .rightToLeft), 225)
        XCTAssertEqual(geometry.center(at: 1, direction: .rightToLeft), -25)
    }

    func testNegativeContainerWidthResolvesToZero() {
        let geometry = ITextShimmerGeometry(
            containerWidth: -10,
            bandFraction: 0.25
        )

        XCTAssertEqual(geometry.containerWidth, 0)
        XCTAssertEqual(geometry.bandWidth, 0)
    }
}
