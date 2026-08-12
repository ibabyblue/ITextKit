import CoreText
import UIKit
import XCTest
@testable import ITextKit

@MainActor
final class ITextDrawingPlanTests: XCTestCase {
    func testSolidFillDrawsVectorPath() throws {
        let image = render(style: .init(fill: .solid(.systemRed)))
        let center = try image.rgba(at: CGPoint(x: 20, y: 20))

        XCTAssertGreaterThan(center.red, 0.7)
        XCTAssertLessThan(center.blue, 0.3)
        XCTAssertGreaterThan(center.alpha, 0.9)
    }

    func testLinearGradientUsesOneContinuousTextBoundsCoordinateSpace() throws {
        let gradient = ITextLinearGradient(
            colors: [UIColor.systemRed, .systemBlue]
        )
        let image = render(style: .init(fill: .linearGradient(gradient)))
        let left = try image.rgba(at: CGPoint(x: 11, y: 20))
        let right = try image.rgba(at: CGPoint(x: 29, y: 20))

        XCTAssertGreaterThan(left.red, left.blue)
        XCTAssertGreaterThan(right.blue, right.red)
    }

    func testTwoPointStrokeIsDrawnOutsideBeforeFill() throws {
        let image = render(style: .init(
            fill: .solid(.systemGreen),
            stroke: .init(paint: .solid(.systemRed), width: 2)
        ))
        let outside = try image.rgba(at: CGPoint(x: 9, y: 20))
        let center = try image.rgba(at: CGPoint(x: 20, y: 20))

        XCTAssertGreaterThan(outside.red, outside.green)
        XCTAssertGreaterThan(center.green, center.red)
    }

    func testLinearGradientStrokeChangesColorAcrossOuterEdge() throws {
        let gradient = ITextLinearGradient(
            colors: [UIColor.systemRed, .systemBlue]
        )
        let image = render(style: .init(
            fill: .solid(.white),
            stroke: .init(paint: .linearGradient(gradient), width: 2)
        ))
        let left = try image.rgba(at: CGPoint(x: 9, y: 20))
        let right = try image.rgba(at: CGPoint(x: 31, y: 20))

        XCTAssertGreaterThan(left.red, left.blue)
        XCTAssertGreaterThan(right.blue, right.red)
    }

    func testSemanticGradientMirrorsInRightToLeftLayout() throws {
        let gradient = ITextLinearGradient(
            colors: [UIColor.systemRed, .systemBlue]
        )
        let image = render(
            style: .init(fill: .linearGradient(gradient)),
            direction: .rightToLeft
        )
        let left = try image.rgba(at: CGPoint(x: 11, y: 20))
        let right = try image.rgba(at: CGPoint(x: 29, y: 20))

        XCTAssertGreaterThan(left.blue, left.red)
        XCTAssertGreaterThan(right.red, right.blue)
    }

    private func render(
        style: ITextUIKitStyle,
        direction: UIUserInterfaceLayoutDirection = .leftToRight
    ) -> UIImage {
        let rect = CGRect(x: 10, y: 10, width: 20, height: 20)
        let path = CGPath(rect: rect, transform: nil)
        let font = CTFontCreateWithName("Helvetica" as CFString, 20, nil)
        let layout = _ITextLayoutResult(
            size: CGSize(width: 40, height: 40),
            typographicBounds: rect,
            inkBounds: rect,
            firstBaseline: 30,
            lastBaseline: 30,
            glyphs: [
                _ITextGlyphRecord(
                    path: path,
                    font: font,
                    glyph: 1,
                    position: .zero,
                    stringRange: CFRange(location: 0, length: 1),
                    foregroundColor: .black,
                    nativeStrokeColor: nil,
                    nativeStrokeWidth: 0
                ),
            ],
            fallbackRuns: [],
            decorations: [],
            isTruncated: false,
            scaleFactor: 1,
            layoutGeneration: 1
        )
        let plan = _ITextDrawingPlan(
            layout: layout,
            style: style,
            gradientBounds: rect,
            traitCollection: UITraitCollection(userInterfaceStyle: .light),
            layoutDirection: direction,
            shadowColor: nil,
            shadowOffset: .zero
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(
            size: CGSize(width: 40, height: 40),
            format: format
        ).image { context in
            plan.draw(in: context.cgContext)
        }
    }
}

private extension UIImage {
    struct RGBA {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
    }

    func rgba(at point: CGPoint) throws -> RGBA {
        let image = try XCTUnwrap(cgImage)
        let data = try XCTUnwrap(image.dataProvider?.data)
        let bytes = CFDataGetBytePtr(data)!
        let x = min(max(Int(point.x), 0), image.width - 1)
        let y = min(max(Int(point.y), 0), image.height - 1)
        let offset = y * image.bytesPerRow + x * 4
        return RGBA(
            red: CGFloat(bytes[offset]) / 255,
            green: CGFloat(bytes[offset + 1]) / 255,
            blue: CGFloat(bytes[offset + 2]) / 255,
            alpha: CGFloat(bytes[offset + 3]) / 255
        )
    }
}
