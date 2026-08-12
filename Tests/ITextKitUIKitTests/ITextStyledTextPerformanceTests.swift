import CoreGraphics
import CoreText
import UIKit
import XCTest
@testable import ITextKit

@MainActor
final class ITextStyledTextPerformanceTests: XCTestCase {
    private let fixture = String(repeating: "Gradient 描边 العربية office ", count: 5)

    func testColdHundredGlyphLayoutPerformance() {
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            for _ in 0..<100 {
                let engine = _ITextLayoutEngine(pathProvider: _ITextGlyphPathCache(
                    countLimit: 2_048,
                    totalCostLimit: 8 * 1_024 * 1_024
                ))
                _ = engine.layout(request())
            }
        }
    }

    func testWarmUnchangedRedrawPerformance() {
        let label = styledLabel()
        label.layoutIfNeeded()
        let generation = label._layoutGeneration

        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            for _ in 0..<100 {
                label.setNeedsDisplay()
                label.layer.displayIfNeeded()
            }
        }
        XCTAssertEqual(label._layoutGeneration, generation)
    }

    func testTenAnimationsDoNotRebuildLayoutOrPaths() {
        let labels = (0..<10).map { _ in styledLabel() }
        labels.forEach { $0.layoutIfNeeded() }
        let generations = labels.map(\._layoutGeneration)

        for frame in 0..<600 {
            for (index, label) in labels.enumerated() {
                label.transform = CGAffineTransform(
                    translationX: CGFloat((frame + index) % 40),
                    y: 0
                )
                label.alpha = frame.isMultiple(of: 2) ? 0.8 : 1
            }
        }

        XCTAssertEqual(labels.map(\._layoutGeneration), generations)
    }

    func testGlyphCacheStaysWithinConfiguredLimits() {
        let cache = _ITextGlyphPathCache(
            countLimit: 64,
            totalCostLimit: 64 * 64
        )
        let font = CTFontCreateWithName("Helvetica" as CFString, 20, nil)
        for glyph in 0..<512 {
            _ = cache.path(
                font: font,
                glyph: CGGlyph(glyph),
                transform: .identity
            ) {
                CGPath(
                    rect: CGRect(x: 0, y: 0, width: 8, height: 8),
                    transform: nil
                )
            }
        }

        XCTAssertLessThanOrEqual(cache.entryCount, 64)
        XCTAssertLessThanOrEqual(cache.estimatedCost, 64 * 64)
    }

    func testTwentyRowScrollComparedWithNativeBaseline() {
        let native = (0..<20).map { _ -> UILabel in
            let label = UILabel(frame: CGRect(x: 0, y: 0, width: 320, height: 60))
            label.text = fixture
            label.font = .systemFont(ofSize: 18)
            return label
        }
        let styled = (0..<20).map { _ in styledLabel() }

        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            native.forEach { $0.layoutIfNeeded(); $0.layer.displayIfNeeded() }
            styled.forEach { $0.layoutIfNeeded(); $0.layer.displayIfNeeded() }
        }
    }

    private func styledLabel() -> ITextStyledLabel {
        let label = ITextStyledLabel(
            frame: CGRect(x: 0, y: 0, width: 320, height: 100)
        )
        label.text = fixture
        label.font = .systemFont(ofSize: 18)
        label.numberOfLines = 0
        label.textStyle = .init(
            fill: .linearGradient(.init(colors: [.systemPink, .systemOrange])),
            stroke: .init(
                paint: .linearGradient(.init(colors: [.white, .black])),
                width: 2
            )
        )
        return label
    }

    private func request() -> _ITextLayoutRequest {
        _ITextLayoutRequest(
            attributedText: NSAttributedString(string: fixture),
            defaultFont: .systemFont(ofSize: 18),
            defaultColor: .label,
            constrainedSize: CGSize(width: 320, height: 500),
            numberOfLines: 0,
            lineBreakMode: .byWordWrapping,
            alignment: .natural,
            baselineAdjustment: .alignBaselines,
            adjustsFontSizeToFitWidth: false,
            minimumScaleFactor: 0,
            allowsTightening: false,
            layoutDirection: .leftToRight,
            displayScale: 3,
            outwardStrokeWidth: 2
        )
    }
}
