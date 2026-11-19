import UIKit
import XCTest
@testable import ITextKit

/// App-hosted and package-hosted performance gates for the real native canvas.
@MainActor
final class ITextCanvasPerformanceTests: XCTestCase {
    func testTwoThousandCharactersSixImages() {
        measureLayout(characters: 2_000, images: 6, budget: 16.67)
    }

    func testTenThousandCharactersTwentyImages() {
        measureLayout(characters: 10_000, images: 20, budget: 16.67)
    }

    func testContinuousDisplayLinkManipulation() async {
        await measureLive(characters: 2_000, images: 6)
    }

    func testContinuousStressDisplayLinkManipulation() async {
        await measureLive(characters: 10_000, images: 20)
    }

    private func measureLive(characters: Int, images: Int) async {
        let (window, canvas) = mounted(characters: characters, images: images)
        defer { window.isHidden = true }
        let baseline = canvas.baseline.generation
        let id = canvas.document.images[0].id
        canvas.beginManipulation(id: id)
        let finished = expectation(description: "600 rendered manipulation frames")
        let driver = CanvasFrameSampler(canvas: canvas, frames: 600) { finished.fulfill() }
        driver.start()
        await fulfillment(of: [finished], timeout: 40)
        driver.stop()
        canvas.endManipulation(cancelled: false)
        XCTAssertEqual(canvas.baseline.generation, baseline)
        XCTAssertGreaterThanOrEqual(driver.work.count, 600)
        record("canvas_live_\(characters)_work_ms", driver.work)
        record("canvas_live_\(characters)_interval_ms", driver.intervals)
        record("canvas_live_\(characters)_target_ms", driver.targets)
        let misses = zip(driver.intervals, driver.targets).filter { $0.0 > $0.1 * 1.5 }.count
        let missRate = Double(misses) / Double(max(1, driver.intervals.count))
        print("CANVAS_METRIC live_\(characters)_missed_interval_ratio=\(missRate)")
        // Simulator scheduling is not a device FPS guarantee. CPU budget is independently gated.
        XCTAssertLessThan(percentile(driver.work, 0.95), 16.67)
    }

    private func measureLayout(characters: Int, images: Int, budget: Double) {
        let (window, canvas) = mounted(characters: characters, images: images)
        defer { window.isHidden = true }
        let baseline = canvas.baseline.generation
        let initialExclusions = canvas.exclusionGeneration
        var loads = 0
        let provider = canvas.imageProvider
        canvas.imageProvider = { key in loads += 1; return provider?(key) }
        canvas.beginManipulation(id: canvas.document.images[0].id)
        var samples: [Double] = []
        for frame in 0..<300 {
            let start = CACurrentMediaTime()
            let phase = CGFloat(frame) / 30
            canvas.updateManipulation(translation: CGPoint(x: sin(phase) * 18, y: 35 + cos(phase) * 18), rotation: sin(phase) * 0.7)
            canvas.layoutIfNeeded()
            canvas.textView.layer.displayIfNeeded()
            if frame >= 30 { samples.append((CACurrentMediaTime() - start) * 1_000) }
        }
        canvas.endManipulation(cancelled: false)
        record("canvas_\(characters)_\(images)_layout_ms", samples)
        print("CANVAS_METRIC baseline_rebuilds=\(canvas.baseline.generation - baseline) exclusions=\(canvas.exclusionGeneration - initialExclusions) image_lookups=\(loads)")
        XCTAssertEqual(canvas.baseline.generation, baseline)
        XCTAssertEqual(loads, images)
        XCTAssertGreaterThan(canvas.exclusionGeneration - initialExclusions, 200)
        XCTAssertLessThan(percentile(samples, 0.95), budget)
        let glyphs = canvas.textView.layoutManager
        XCTAssertEqual(glyphs.glyphRange(for: canvas.textView.textContainer).length, glyphs.numberOfGlyphs)
    }

    private func mounted(characters: Int, images: Int) -> (UIWindow, ITextCanvasView) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let controller = UIViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        let canvas = ITextCanvasView(frame: CGRect(x: 0, y: 60, width: 390, height: 650))
        var config = ITextCanvasConfiguration()
        config.font = .systemFont(ofSize: 17)
        canvas.configuration = config
        // Decoded image data is caller-owned. Exercise textured image layers, without putting
        // network loading or image decoding into the measured manipulation interval.
        let bitmap = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 192)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 256, height: 192))
            UIColor.systemYellow.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 160, y: 20, width: 60, height: 60))
        }
        canvas.imageProvider = { _ in bitmap }
        let source = String(repeating: "文字环绕性能测试，完整字符👨‍👩‍👧‍👦。Text wrapping العربية.\n", count: characters / 20 + 1)
        let text = String(source.prefix(characters))
        let media = (0..<images).map { index in
            ITextCanvasImage(resourceKey: "\(index)", anchorOffset: index * text.utf16.count / images,
                xRatio: index.isMultiple(of: 2) ? 0.15 : 0.6, yOffset: 0.1, widthRatio: 0.22,
                aspectRatio: 1.3, rotationDegrees: index.isMultiple(of: 2) ? 15 : -15)
        }
        canvas.document = .init(text: text, images: media)
        controller.view.addSubview(canvas)
        canvas.layoutIfNeeded()
        return (window, canvas)
    }

    private func percentile(_ samples: [Double], _ quantile: Double) -> Double {
        let sorted = samples.sorted()
        return sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, max(0, Int(ceil(Double(sorted.count) * quantile)) - 1))]
    }

    private func record(_ name: String, _ samples: [Double]) {
        let output = "CANVAS_METRIC \(name) n=\(samples.count) p50=\(percentile(samples, 0.5)) p95=\(percentile(samples, 0.95)) max=\(samples.max() ?? 0)"
        print(output)
        let attachment = XCTAttachment(string: output)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// Real display-link pacing includes UIKit drawing and run-loop scheduling between samples.
@MainActor
private final class CanvasFrameSampler: NSObject {
    let canvas: ITextCanvasView
    let frames: Int
    let completion: () -> Void
    var work: [Double] = []
    var intervals: [Double] = []
    var targets: [Double] = []
    var previous: CFTimeInterval?
    var link: CADisplayLink?

    init(canvas: ITextCanvasView, frames: Int, completion: @escaping () -> Void) {
        self.canvas = canvas
        self.frames = frames
        self.completion = completion
    }

    func start() {
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFramesPerSecond = 60
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() { link?.invalidate(); link = nil }

    @objc func tick(_ link: CADisplayLink) {
        let start = CACurrentMediaTime()
        if let previous {
            intervals.append((link.timestamp - previous) * 1_000)
            targets.append((link.targetTimestamp - link.timestamp) * 1_000)
        }
        previous = link.timestamp
        let phase = CGFloat(work.count) / 20
        canvas.updateManipulation(translation: CGPoint(x: sin(phase) * 18, y: 35 + cos(phase) * 18), rotation: sin(phase) * 0.7)
        canvas.layoutIfNeeded()
        work.append((CACurrentMediaTime() - start) * 1_000)
        if work.count >= frames { stop(); completion() }
    }
}
