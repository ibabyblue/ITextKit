import CoreGraphics
import XCTest
@testable import ITextKit

final class ITextStyleTests: XCTestCase {
    func testStrokeResolvesToOutwardPointWidthAndDoubleCenteredLineWidth() {
        let stroke = ITextStroke(paint: ITextPaint.solid("ink"), width: 2)

        XCTAssertEqual(stroke.width, 2)
        XCTAssertEqual(stroke._resolved?.outwardWidth, 2)
        XCTAssertEqual(stroke._resolved?.centeredLineWidth, 4)
    }

    func testStrokeResolutionClampsInvalidAndExcessiveWidths() {
        XCTAssertEqual(
            ITextStroke(paint: ITextPaint.solid("ink"), width: -1)
                ._resolved?.outwardWidth,
            0
        )
        XCTAssertEqual(
            ITextStroke(paint: ITextPaint.solid("ink"), width: .infinity)
                ._resolved?.outwardWidth,
            0
        )
        XCTAssertEqual(
            ITextStroke(paint: ITextPaint.solid("ink"), width: 100)
                ._resolved?.outwardWidth,
            64
        )
    }

    func testColorsInitializerDistributesLocationsEvenly() {
        let gradient = ITextLinearGradient(
            colors: ["a", "b", "c"],
            startPoint: .leading,
            endPoint: .trailing
        )

        XCTAssertEqual(gradient.stops.map(\.location), [0, 0.5, 1])
    }

    func testGradientResolutionHandlesEmptyAndOneColorInput() {
        XCTAssertNil(
            ITextLinearGradient<String>(colors: [])
                ._resolved(isRightToLeft: false)
        )

        let one = ITextLinearGradient(colors: ["a"])
        XCTAssertEqual(
            one._resolved(isRightToLeft: false)?.colors,
            ["a"]
        )
    }

    func testGradientResolutionClampsAndStableSortsStops() {
        let gradient = ITextLinearGradient(stops: [
            .init(color: "late", location: 2),
            .init(color: "firstHard", location: 0.5),
            .init(color: "secondHard", location: 0.5),
            .init(color: "nan", location: .nan),
        ])

        let resolved = gradient._resolved(isRightToLeft: false)

        XCTAssertEqual(resolved?.locations, [0.5, 0.5, 1, 1])
        XCTAssertEqual(
            resolved?.colors,
            ["firstHard", "secondHard", "late", "nan"]
        )
    }

    func testSemanticPointsMirrorWhileUnitPointsRemainPhysical() {
        let ltr = ITextLinearGradient(colors: [0, 1])
            ._resolved(isRightToLeft: false)
        let rtl = ITextLinearGradient(colors: [0, 1])
            ._resolved(isRightToLeft: true)

        XCTAssertEqual(ltr?.startPoint, CGPoint(x: 0, y: 0.5))
        XCTAssertEqual(ltr?.endPoint, CGPoint(x: 1, y: 0.5))
        XCTAssertEqual(rtl?.startPoint, CGPoint(x: 1, y: 0.5))
        XCTAssertEqual(rtl?.endPoint, CGPoint(x: 0, y: 0.5))

        let physical = ITextLinearGradient(
            colors: [0, 1],
            startPoint: .unit(x: 0.2, y: 0.3),
            endPoint: .unit(x: 0.8, y: 0.7)
        )

        XCTAssertEqual(
            physical._resolved(isRightToLeft: true)?.startPoint,
            CGPoint(x: 0.2, y: 0.3)
        )
        XCTAssertEqual(
            physical._resolved(isRightToLeft: true)?.endPoint,
            CGPoint(x: 0.8, y: 0.7)
        )
    }

    func testEqualGradientPointsResolveToFirstSolidColor() {
        let gradient = ITextLinearGradient(
            colors: ["first", "last"],
            startPoint: .center,
            endPoint: .center
        )

        XCTAssertEqual(
            gradient._resolvedPaint(isRightToLeft: false),
            .solid("first")
        )
    }
}
