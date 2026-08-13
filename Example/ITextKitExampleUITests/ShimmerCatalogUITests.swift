import XCTest

final class ShimmerCatalogUITests: ITextKitExampleUITestCase {
    func testSwiftUIShimmerTeachesCompositionAndToggle() {
        let app = open("Shimmer"); assertSections(["Plain text", "Attributed text", "Styled fill + stroke", "Configuration", "Correct modifier order"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)["code.swiftui.shimmer.styled"].exists)
        let toggle = app.switches["Shimmer active"]; reveal(toggle, in: app); toggle.tap()
        XCTAssertTrue(app.staticTexts["Shimmer: Off"].waitForExistence(timeout: 2))
    }
    func testUIKitShimmerTeachesNativeLabelBehavior() {
        let app = open("Shimmer Label", inUIKit: true); assertSections(["Plain label", "Attributed label", "Styled fill + stroke", "Configuration", "Intrinsic size"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)["code.uikit.shimmer.styled"].exists)
        let toggle = app.switches["Shimmer active"]; reveal(toggle, in: app); toggle.tap()
        XCTAssertTrue(app.staticTexts["Shimmer: Off"].exists)
    }

    func testSwiftUIShimmerDoesNotAnimateCardBackground() {
        let app = open("Shimmer")
        let probe = app.staticTexts["SwiftUI shimmer background probe"]
        reveal(probe, in: app)
        let point = CGPoint(x: app.windows.firstMatch.frame.maxX - 50, y: probe.frame.midY)
        var samples: [[UInt8]] = []
        for _ in 0..<20 {
            samples.append(pixelRGBA(in: app.screenshot().image, at: point))
            Thread.sleep(forTimeInterval: 0.08)
        }
        let variation = (0..<3).map { channel in
            let values = samples.map { Int($0[channel]) }
            return (values.max() ?? 0) - (values.min() ?? 0)
        }.max() ?? 0
        XCTAssertLessThanOrEqual(variation, 3)
    }

    private func assertSections(_ labels: [String], in app: XCUIApplication) { labels.forEach { XCTAssertTrue(app.staticTexts[$0].exists) } }

    private func pixelRGBA(in image: UIImage, at point: CGPoint) -> [UInt8] {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { _ in image.draw(at: CGPoint(x: -point.x, y: -point.y)) }
        guard let source = image.cgImage else { return [0, 0, 0, 0] }
        var pixel = [UInt8](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes { bytes in
            CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.draw(source, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return pixel
    }
}
