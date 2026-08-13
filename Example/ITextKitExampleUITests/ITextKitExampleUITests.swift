import UIKit
import XCTest

final class ITextKitExampleUITests: XCTestCase {
    func testStyledPerformanceLaunchArgumentShowsTwentyRowFixture() {
        let app = XCUIApplication()
        app.launchArguments = ["-ITextStyledPerformance"]
        app.launch()

        XCTAssertTrue(
            app.otherElements["Styled performance fixture"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertEqual(
            app.staticTexts.matching(
                NSPredicate(format: "label BEGINSWITH 'Styled row '")
            ).count,
            20
        )
    }

    func testSwiftUIShimmerDoesNotAnimateCardBackground() {
        let app = XCUIApplication()
        app.launch()
        app.swipeUp()
        app.swipeUp()

        let shimmerText = app.staticTexts["SwiftUI shimmer"]
        XCTAssertTrue(shimmerText.waitForExistence(timeout: 2))

        let samplePoint = CGPoint(
            x: app.windows.firstMatch.frame.maxX - 50,
            y: shimmerText.frame.midY
        )
        var samples: [[UInt8]] = []

        // Cover more than the default 1.5-second sweep so the moving band must
        // cross this background-only point if the card is copied by Shimmer.
        for _ in 0..<20 {
            samples.append(pixelRGBA(in: app.screenshot().image, at: samplePoint))
            Thread.sleep(forTimeInterval: 0.08)
        }

        let maximumChannelVariation = (0..<3).map { channel in
            let values = samples.map { Int($0[channel]) }
            return (values.max() ?? 0) - (values.min() ?? 0)
        }.max() ?? 0

        XCTAssertLessThanOrEqual(
            maximumChannelVariation,
            3,
            "The card background changed while only its text should shimmer. " +
                "frame=\(shimmerText.frame), samples=\(samples)"
        )
    }

    func testSwiftUIRotatorUsesSingleLineMessages() {
        let app = XCUIApplication()
        app.launch()

        let shortText = app.staticTexts["A short message"]
        XCTAssertTrue(shortText.waitForExistence(timeout: 2))
        let shortHeight = shortText.frame.height
        XCTAssertTrue(app.buttons["Start"].exists)
        XCTAssertTrue(app.buttons["Pause"].exists)
        XCTAssertTrue(app.buttons["Resume"].exists)
        XCTAssertTrue(app.buttons["Stop"].exists)
        XCTAssertTrue(app.staticTexts["Attributed rotator"].exists)
        XCTAssertTrue(app.staticTexts["Attributed overflow-only marquee"].exists)

        app.buttons["Pause"].tap()
        app.buttons["Resume"].tap()

        let nextText = app.staticTexts["Loading your space"]
        XCTAssertTrue(nextText.waitForExistence(timeout: 5))
        XCTAssertEqual(nextText.frame.height, shortHeight, accuracy: 1)

        keepScreenshot(of: app, named: "SwiftUI Example")

        app.swipeUp()
        let richMarquee = app.staticTexts[
            "This bold green attributed marquee includes an underlined visual phrase and keeps moving as one line."
        ]
        XCTAssertTrue(richMarquee.waitForExistence(timeout: 2))
        keepScreenshot(of: app, named: "SwiftUI Attributed Marquee")

        app.swipeUp()
        XCTAssertTrue(app.staticTexts["SwiftUI shimmer"].waitForExistence(timeout: 2))
        keepScreenshot(of: app, named: "SwiftUI Shimmer")

        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Plain typewriter"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Attributed typewriter"].exists)
        XCTAssertTrue(app.otherElements[
            "A plain typewriter grows wider, then wraps and grows taller."
        ].exists)
        XCTAssertTrue(app.otherElements[
            "Rich 👨‍👩‍👧‍👦 typewriter text keeps its color, weight, and underline while it grows."
        ].exists)
        XCTAssertTrue(app.buttons["Replay Typewriter"].exists)
        app.buttons["Replay Typewriter"].tap()
        keepScreenshot(of: app, named: "SwiftUI Typewriter")
    }

    func testUIKitTabContainsNativeControls() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["UIKit"].tap()

        XCTAssertTrue(app.staticTexts["Plain rotator"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Attributed rotator"].exists)
        XCTAssertTrue(app.staticTexts["Attributed overflow-only marquee"].exists)
        XCTAssertTrue(app.buttons["Start"].exists)
        XCTAssertTrue(app.buttons["Pause"].exists)
        XCTAssertTrue(app.buttons["Resume"].exists)
        XCTAssertTrue(app.buttons["Stop"].exists)
        XCTAssertTrue(app.staticTexts["Settled index: 1"].waitForExistence(timeout: 5))
        let marquee = app.otherElements[
            "The UIKit marquee waits at leading, then loops this overflowing message seamlessly."
        ]
        XCTAssertTrue(marquee.exists)

        keepScreenshot(of: app, named: "UIKit Example")

        app.swipeUp()
        let richMarquee = app.otherElements[
            "This bold green UIKit attributed marquee is underlined and moves as one native line."
        ]
        XCTAssertTrue(richMarquee.waitForExistence(timeout: 2))
        keepScreenshot(of: app, named: "UIKit Attributed Marquee")

        app.swipeUp()
        XCTAssertTrue(app.staticTexts["UIKit shimmer"].waitForExistence(timeout: 2))
        keepScreenshot(of: app, named: "UIKit Shimmer")

        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Plain typewriter"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Attributed typewriter"].exists)
        XCTAssertTrue(app.otherElements[
            "A plain UIKit typewriter grows wider, then wraps and grows taller."
        ].exists)
        XCTAssertTrue(app.otherElements[
            "Rich 👨‍👩‍👧‍👦 UIKit typewriter text keeps its color, weight, and underline while it grows."
        ].exists)
        XCTAssertTrue(app.buttons["Replay Typewriter"].exists)
        app.buttons["Replay Typewriter"].tap()
        keepScreenshot(of: app, named: "UIKit Typewriter")
    }

    private func keepScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func pixelRGBA(in image: UIImage, at point: CGPoint) -> [UInt8] {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let onePointImage = UIGraphicsImageRenderer(
            size: CGSize(width: 1, height: 1),
            format: format
        ).image { _ in
            image.draw(at: CGPoint(x: -point.x, y: -point.y))
        }

        guard let source = onePointImage.cgImage else {
            XCTFail("The UI screenshot did not provide CGImage data.")
            return [0, 0, 0, 0]
        }

        var pixel = [UInt8](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes { bytes in
            let context = CGContext(
                data: bytes.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(source, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return pixel
    }
}
