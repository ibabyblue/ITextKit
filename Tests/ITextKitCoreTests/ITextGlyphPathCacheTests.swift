import CoreGraphics
import CoreText
import XCTest
@testable import ITextKit

final class ITextGlyphPathCacheTests: XCTestCase {
    func testEqualFontGlyphAndTransformBuildPathOnce() {
        var buildCount = 0
        let cache = _ITextGlyphPathCache(
            countLimit: 8,
            totalCostLimit: 4_096
        )
        let font = CTFontCreateWithName("Helvetica" as CFString, 20, nil)

        let first = cache.path(font: font, glyph: 12, transform: .identity) {
            buildCount += 1
            return CGPath(
                rect: CGRect(x: 0, y: 0, width: 10, height: 10),
                transform: nil
            )
        }
        let second = cache.path(font: font, glyph: 12, transform: .identity) {
            buildCount += 1
            return nil
        }

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertEqual(buildCount, 1)
        XCTAssertEqual(cache.entryCount, 1)
    }

    func testMissingPathIsCachedInsteadOfRepeatedlyBuilt() {
        var buildCount = 0
        let cache = _ITextGlyphPathCache(
            countLimit: 8,
            totalCostLimit: 4_096
        )
        let font = CTFontCreateWithName("Helvetica" as CFString, 20, nil)

        for _ in 0..<2 {
            let path = cache.path(font: font, glyph: 0, transform: .identity) {
                buildCount += 1
                return nil
            }
            XCTAssertNil(path)
        }

        XCTAssertEqual(buildCount, 1)
        XCTAssertEqual(cache.entryCount, 1)
    }

    func testDifferentGlyphOrTransformUsesDifferentEntries() {
        var buildCount = 0
        let cache = _ITextGlyphPathCache(
            countLimit: 8,
            totalCostLimit: 4_096
        )
        let font = CTFontCreateWithName("Helvetica" as CFString, 20, nil)

        for glyph in [CGGlyph(1), CGGlyph(2)] {
            _ = cache.path(font: font, glyph: glyph, transform: .identity) {
                buildCount += 1
                return CGPath(
                    rect: CGRect(x: 0, y: 0, width: 4, height: 4),
                    transform: nil
                )
            }
        }
        _ = cache.path(
            font: font,
            glyph: 1,
            transform: CGAffineTransform(scaleX: 2, y: 2)
        ) {
            buildCount += 1
            return CGPath(
                rect: CGRect(x: 0, y: 0, width: 8, height: 8),
                transform: nil
            )
        }

        XCTAssertEqual(buildCount, 3)
        XCTAssertEqual(cache.entryCount, 3)
    }

    func testRemoveAllObjectsForcesRebuildAndResetsCost() {
        var buildCount = 0
        let cache = _ITextGlyphPathCache(
            countLimit: 8,
            totalCostLimit: 4_096
        )
        let font = CTFontCreateWithName("Helvetica" as CFString, 20, nil)
        let build: () -> CGPath? = {
            buildCount += 1
            return CGPath(
                rect: CGRect(x: 0, y: 0, width: 4, height: 4),
                transform: nil
            )
        }

        _ = cache.path(
            font: font,
            glyph: 1,
            transform: .identity,
            build: build
        )
        XCTAssertGreaterThan(cache.estimatedCost, 0)

        cache.removeAllObjects()

        XCTAssertEqual(cache.entryCount, 0)
        XCTAssertEqual(cache.estimatedCost, 0)
        _ = cache.path(
            font: font,
            glyph: 1,
            transform: .identity,
            build: build
        )
        XCTAssertEqual(buildCount, 2)
    }
}
