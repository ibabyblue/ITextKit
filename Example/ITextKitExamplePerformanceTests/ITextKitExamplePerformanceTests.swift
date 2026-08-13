import QuartzCore
import UIKit
import XCTest
@testable import ITextKit

@MainActor
final class ITextKitExamplePerformanceTests: XCTestCase {
    private let fixture = String(
        repeating: "Gradient 描边 العربية office ",
        count: 5
    )

    func testColdHundredGlyphLayoutPerformance() {
        var samples: [Double] = []
        samples.reserveCapacity(100)

        for _ in 0..<100 {
            autoreleasepool {
                let start = CACurrentMediaTime()
                let label = styledLabel()
                label.layoutIfNeeded()
                label.layer.displayIfNeeded()
                samples.append((CACurrentMediaTime() - start) * 1_000)
            }
        }

        let result = record(
            name: "cold_layout_and_plan_ms",
            samples: samples
        )
        XCTAssertLessThanOrEqual(result.p95, 4)
    }

    func testWarmUnchangedRedrawPerformance() {
        let label = styledLabel()
        label.layoutIfNeeded()
        label.layer.displayIfNeeded()
        let generation = label._layoutGeneration
        var samples: [Double] = []
        samples.reserveCapacity(100)

        for _ in 0..<100 {
            let start = CACurrentMediaTime()
            label.setNeedsDisplay()
            label.layer.displayIfNeeded()
            samples.append((CACurrentMediaTime() - start) * 1_000)
        }

        let result = record(name: "warm_redraw_ms", samples: samples)
        XCTAssertLessThanOrEqual(result.p95, 1)
        XCTAssertEqual(label._layoutGeneration, generation)
    }

    func testSixMarqueesDoNotRebuildDuringSteadyTravel() {
        let controller = UIViewController()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()

        var marquees: [ITextMarqueeView] = []
        for index in 0..<6 {
            let marquee = ITextMarqueeView(
                text: fixture + String(index),
                configuration: .init(
                    speed: 40,
                    spacing: 24,
                    initialDelay: 0
                )
            )
            marquee.frame = CGRect(
                x: 0,
                y: CGFloat(index) * 36,
                width: 300,
                height: 32
            )
            if index == 2 || index == 3 {
                marquee.textStyle = style
            }
            if index == 5 {
                marquee.semanticContentAttribute = .forceRightToLeft
            }
            controller.view.addSubview(marquee)
            marquees.append(marquee)
        }
        controller.view.layoutIfNeeded()
        marquees.forEach { $0.layoutIfNeeded() }
        let labels = marquees.flatMap(\._movingLabels)
        labels.forEach { $0.layer.displayIfNeeded() }
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        labels.forEach { $0.layer.displayIfNeeded() }

        XCTAssertTrue(marquees.allSatisfy(\._hasActiveTravelAnimation))
        let measurements = marquees.map(\._measurementGeneration)
        let layouts = labels.map(\._layoutGeneration)
        let drawings = labels.map(\._drawingGeneration)
        let cacheCount = _ITextGlyphPathCache.shared.entryCount
        let cacheCost = _ITextGlyphPathCache.shared.estimatedCost

        RunLoop.main.run(until: Date().addingTimeInterval(10))

        XCTAssertEqual(marquees.map(\._measurementGeneration), measurements)
        XCTAssertEqual(labels.map(\._layoutGeneration), layouts)
        XCTAssertEqual(labels.map(\._drawingGeneration), drawings)
        XCTAssertEqual(_ITextGlyphPathCache.shared.entryCount, cacheCount)
        XCTAssertEqual(_ITextGlyphPathCache.shared.estimatedCost, cacheCost)
        recordScalar(name: "marquee_measurement_rebuilds", value: 0)
        recordScalar(name: "marquee_layout_rebuilds", value: 0)
        recordScalar(name: "marquee_drawing_rebuilds", value: 0)
        recordScalar(name: "marquee_path_rebuilds", value: 0)
        window.isHidden = true
    }

    func testFiveShimmersDoNotRebuildLayoutOrPaths() {
        let controller = UIViewController()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()

        var shimmers: [ITextShimmerLabel] = []
        for index in 0..<5 {

            let shimmer = ITextShimmerLabel(frame: CGRect(
                x: 0,
                y: CGFloat(index) * 36,
                width: 300,
                height: 32
            ))
            shimmer.text = fixture
            shimmer.textStyle = style
            shimmer.isShimmering = true
            controller.view.addSubview(shimmer)
            shimmers.append(shimmer)
        }
        controller.view.layoutIfNeeded()
        shimmers.forEach { $0.layoutIfNeeded() }

        let labels = shimmers.flatMap(styledLabels(in:))
        let generations = labels.map(\._layoutGeneration)
        let cacheCount = _ITextGlyphPathCache.shared.entryCount
        let cacheCost = _ITextGlyphPathCache.shared.estimatedCost

        RunLoop.main.run(until: Date().addingTimeInterval(10))

        XCTAssertEqual(labels.map(\._layoutGeneration), generations)
        XCTAssertEqual(_ITextGlyphPathCache.shared.entryCount, cacheCount)
        XCTAssertEqual(_ITextGlyphPathCache.shared.estimatedCost, cacheCost)
        recordScalar(name: "shimmer_layout_rebuilds", value: 0)
        recordScalar(name: "shimmer_path_rebuilds", value: 0)
        window.isHidden = true
    }

    func testGlyphCacheStaysWithinConfiguredLimits() {
        let cache = _ITextGlyphPathCache(
            countLimit: 2_048,
            totalCostLimit: 8 * 1_024 * 1_024
        )
        let engine = _ITextLayoutEngine(pathProvider: cache)
        for index in 0..<100 {
            let text = NSAttributedString(
                string: fixture + String(index),
                attributes: [.font: UIFont.systemFont(ofSize: 18)]
            )
            _ = engine.layout(request(for: text))
        }

        XCTAssertLessThanOrEqual(cache.entryCount, 2_048)
        XCTAssertLessThanOrEqual(cache.estimatedCost, 8 * 1_024 * 1_024)
        recordScalar(name: "cache_peak_count", value: Double(cache.entryCount))
        recordScalar(name: "cache_peak_cost_bytes", value: Double(cache.estimatedCost))
    }

    func testTwentyRowScrollComparedWithNativeBaseline() {
        let native = makeScrollView(styled: false)
        let styled = makeScrollView(styled: true)
        native.layoutIfNeeded()
        styled.layoutIfNeeded()
        native.layer.displayIfNeeded()
        styled.layer.displayIfNeeded()

        let nativeSamples = scrollSamples(for: native)
        let styledSamples = scrollSamples(for: styled)
        let nativeResult = record(
            name: "native_twenty_row_frame_ms",
            samples: nativeSamples
        )
        let styledResult = record(
            name: "styled_twenty_row_frame_ms",
            samples: styledSamples
        )
        let delta = styledResult.p95 - nativeResult.p95
        recordScalar(name: "styled_native_p95_delta_ms", value: delta)
        XCTAssertLessThanOrEqual(delta, 1)
    }

    private var style: ITextUIKitStyle {
        .init(
            fill: .linearGradient(.init(colors: [.systemPink, .systemOrange])),
            stroke: .init(
                paint: .linearGradient(.init(colors: [.white, .black])),
                width: 2
            )
        )
    }

    private func styledLabel() -> ITextStyledLabel {
        let label = ITextStyledLabel(
            frame: CGRect(x: 0, y: 0, width: 320, height: 100)
        )
        label.text = fixture
        label.font = .systemFont(ofSize: 18)
        label.numberOfLines = 0
        label.textStyle = style
        return label
    }

    private func request(
        for text: NSAttributedString
    ) -> _ITextLayoutRequest {
        _ITextLayoutRequest(
            attributedText: text,
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
            displayScale: UIScreen.main.scale,
            outwardStrokeWidth: 2
        )
    }

    private func styledLabels(in view: UIView) -> [ITextStyledLabel] {
        var result: [ITextStyledLabel] = []
        if let label = view as? ITextStyledLabel {
            result.append(label)
        }
        for subview in view.subviews {
            result.append(contentsOf: styledLabels(in: subview))
        }
        return result
    }

    private func makeScrollView(styled: Bool) -> UIScrollView {
        let scroll = UIScrollView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480)
        )
        for index in 0..<20 {
            let frame = CGRect(
                x: 0,
                y: CGFloat(index) * 60,
                width: 320,
                height: 60
            )
            let label: UILabel
            if styled {
                let value = ITextStyledLabel(frame: frame)
                value.textStyle = style
                label = value
            } else {
                label = UILabel(frame: frame)
            }
            label.text = "Row \(index) — \(fixture)"
            label.font = .systemFont(ofSize: 18)
            label.numberOfLines = 1
            scroll.addSubview(label)
        }
        scroll.contentSize = CGSize(width: 320, height: 1_200)
        return scroll
    }

    private func scrollSamples(for scroll: UIScrollView) -> [Double] {
        var samples: [Double] = []
        samples.reserveCapacity(120)
        for frame in 0..<120 {
            let start = CACurrentMediaTime()
            scroll.contentOffset.y = CGFloat(frame % 60) * 8
            scroll.layoutIfNeeded()
            scroll.layer.displayIfNeeded()
            CATransaction.flush()
            samples.append((CACurrentMediaTime() - start) * 1_000)
        }
        return samples
    }

    @discardableResult
    private func record(
        name: String,
        samples: [Double]
    ) -> (p50: Double, p95: Double, maximum: Double) {
        let sorted = samples.sorted()
        let result = (
            percentile(sorted, 0.50),
            percentile(sorted, 0.95),
            sorted.last ?? 0
        )
        let payload = "\(name): count=\(samples.count), "
            + "p50=\(result.0), p95=\(result.1), max=\(result.2)"
        let attachment = XCTAttachment(string: payload)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return result
    }

    private func recordScalar(name: String, value: Double) {
        let attachment = XCTAttachment(string: "\(name): \(value)")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func percentile(
        _ sorted: [Double],
        _ quantile: Double
    ) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = Int(ceil(Double(sorted.count) * quantile)) - 1
        return sorted[min(max(index, 0), sorted.count - 1)]
    }
}
