import CoreText
import UIKit
import XCTest
@testable import ITextKit

final class ITextLayoutEngineTests: XCTestCase {
    private let engine = _ITextLayoutEngine(
        pathProvider: _ITextGlyphPathCache(
            countLimit: 128,
            totalCostLimit: 512 * 1_024
        )
    )

    func testOutwardStrokeExpandsSizeWithoutMovingBaselineRelativeToText() {
        let plain = layout("Outline", width: 300, stroke: 0)
        let stroked = layout("Outline", width: 300, stroke: 2)

        XCTAssertEqual(stroked.size.width, plain.size.width + 4, accuracy: 0.5)
        XCTAssertEqual(stroked.size.height, plain.size.height + 4, accuracy: 0.5)
        XCTAssertEqual(stroked.firstBaseline, plain.firstBaseline + 2, accuracy: 0.5)
    }

    func testConstrainedWidthReservesStrokeAndCanWrapEarlier() {
        let plain = layout("A wrapping sentence", width: 120, stroke: 0)
        let stroked = layout("A wrapping sentence", width: 120, stroke: 3)

        XCTAssertLessThanOrEqual(stroked.size.width, 120)
        XCTAssertGreaterThanOrEqual(stroked.size.height, plain.size.height)
    }

    func testEmptyTextHasZeroSizeAndNoRecords() {
        let result = layout("", width: 120, stroke: 3)

        XCTAssertEqual(result.size, .zero)
        XCTAssertTrue(result.glyphs.isEmpty)
        XCTAssertTrue(result.fallbackRuns.isEmpty)
        XCTAssertTrue(result.decorations.isEmpty)
    }

    func testCombiningArabicAndLigatureInputProducesFinitePlacedRecords() {
        let result = layout("A\u{0301} العربية office", width: 180, stroke: 1)

        XCTAssertGreaterThan(result.glyphs.count + result.fallbackRuns.count, 0)
        XCTAssertTrue(result.size.width.isFinite)
        XCTAssertTrue(result.size.height.isFinite)
        XCTAssertFalse(result.inkBounds.isNull)
    }

    func testColorEmojiUsesFallbackRecord() {
        let result = layout("👨‍👩‍👧‍👦", width: 180, stroke: 2)

        XCTAssertFalse(result.fallbackRuns.isEmpty)
    }

    func testAllSingleLineTruncationModesReportTruncation() {
        for mode in [
            NSLineBreakMode.byTruncatingHead,
            .byTruncatingMiddle,
            .byTruncatingTail,
        ] {
            let result = layout(
                "A sentence that cannot fit on one line",
                width: 90,
                numberOfLines: 1,
                lineBreakMode: mode
            )

            XCTAssertTrue(result.isTruncated, "Expected truncation for \(mode)")
            XCTAssertLessThanOrEqual(result.size.width, 90)
        }
    }

    func testAlignmentAndDirectionProduceFiniteGeometry() {
        for direction in [
            UIUserInterfaceLayoutDirection.leftToRight,
            .rightToLeft,
        ] {
            for alignment in [
                NSTextAlignment.natural,
                .center,
                .right,
            ] {
                let result = layout(
                    "Alignment",
                    width: 160,
                    alignment: alignment,
                    layoutDirection: direction
                )

                XCTAssertTrue(result.typographicBounds.minX.isFinite)
                XCTAssertTrue(result.typographicBounds.maxX.isFinite)
            }
        }
    }

    func testMinimumScaleFactorShrinksSingleLineContent() {
        let natural = layout(
            "A long single line",
            width: 500,
            numberOfLines: 1
        )
        let fitted = layout(
            "A long single line",
            width: 80,
            numberOfLines: 1,
            adjustsFontSizeToFitWidth: true,
            minimumScaleFactor: 0.25
        )

        XCTAssertLessThan(fitted.scaleFactor, 1)
        XCTAssertGreaterThanOrEqual(fitted.scaleFactor, 0.25)
        XCTAssertLessThan(fitted.size.width, natural.size.width)
        XCTAssertLessThanOrEqual(fitted.size.width, 80)
    }

    func testUnderlineAndStrikethroughProduceDecorationRecords() {
        let attributed = NSAttributedString(
            string: "Decorated",
            attributes: [
                .font: UIFont.systemFont(ofSize: 24),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            ]
        )
        let result = engine.layout(request(attributed, width: 180))

        XCTAssertEqual(result.decorations.filter { $0.kind == .underline }.count, 1)
        XCTAssertEqual(result.decorations.filter { $0.kind == .strikethrough }.count, 1)
    }

    func testRepeatedEqualRequestsProduceEqualGeometry() {
        let request = request(
            NSAttributedString(string: "Stable geometry"),
            width: 140,
            stroke: 1
        )
        let first = engine.layout(request)
        let second = engine.layout(request)

        XCTAssertEqual(first.size, second.size)
        XCTAssertEqual(first.typographicBounds, second.typographicBounds)
        XCTAssertEqual(first.inkBounds, second.inkBounds)
        XCTAssertEqual(first.firstBaseline, second.firstBaseline)
        XCTAssertEqual(first.lastBaseline, second.lastBaseline)
        XCTAssertGreaterThan(second.layoutGeneration, first.layoutGeneration)
    }

    private func layout(
        _ text: String,
        width: CGFloat,
        stroke: CGFloat = 0,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byWordWrapping,
        alignment: NSTextAlignment = .natural,
        layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight,
        adjustsFontSizeToFitWidth: Bool = false,
        minimumScaleFactor: CGFloat = 0
    ) -> _ITextLayoutResult {
        engine.layout(request(
            NSAttributedString(string: text),
            width: width,
            stroke: stroke,
            numberOfLines: numberOfLines,
            lineBreakMode: lineBreakMode,
            alignment: alignment,
            layoutDirection: layoutDirection,
            adjustsFontSizeToFitWidth: adjustsFontSizeToFitWidth,
            minimumScaleFactor: minimumScaleFactor
        ))
    }

    private func request(
        _ text: NSAttributedString,
        width: CGFloat,
        stroke: CGFloat = 0,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byWordWrapping,
        alignment: NSTextAlignment = .natural,
        layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight,
        adjustsFontSizeToFitWidth: Bool = false,
        minimumScaleFactor: CGFloat = 0
    ) -> _ITextLayoutRequest {
        _ITextLayoutRequest(
            attributedText: text,
            defaultFont: .systemFont(ofSize: 24),
            defaultColor: .label,
            constrainedSize: CGSize(
                width: width,
                height: .greatestFiniteMagnitude
            ),
            numberOfLines: numberOfLines,
            lineBreakMode: lineBreakMode,
            alignment: alignment,
            baselineAdjustment: .alignBaselines,
            adjustsFontSizeToFitWidth: adjustsFontSizeToFitWidth,
            minimumScaleFactor: minimumScaleFactor,
            allowsTightening: false,
            layoutDirection: layoutDirection,
            displayScale: 3,
            outwardStrokeWidth: stroke
        )
    }
}
