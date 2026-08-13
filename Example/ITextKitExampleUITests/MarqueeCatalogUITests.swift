import UIKit
import XCTest

final class MarqueeCatalogUITests: ITextKitExampleUITestCase {
    func testSwiftUINativeMarqueePlaybackControlsVisibleTravel() throws {
        let app = open("Marquee")
        let windowFrame = app.windows.firstMatch.frame
        let marquee = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", Self.overflowText)
        ).firstMatch
        scrollToVisible(marquee, in: app, windowFrame: windowFrame, upward: false)

        Thread.sleep(forTimeInterval: 1.2)
        let runningStart = try croppedScreenshot(of: marquee, windowFrame: windowFrame)
        Thread.sleep(forTimeInterval: 0.3)
        let runningEnd = try croppedScreenshot(of: marquee, windowFrame: windowFrame)
        XCTAssertNotEqual(runningStart, runningEnd, "Test precondition: marquee must move")

        tapPlaybackButton("Pause", in: app)

        scrollToVisible(marquee, in: app, windowFrame: windowFrame, upward: true)
        Thread.sleep(forTimeInterval: 0.2)
        let pausedStart = try croppedScreenshot(of: marquee, windowFrame: windowFrame)
        Thread.sleep(forTimeInterval: 0.3)
        let pausedEnd = try croppedScreenshot(of: marquee, windowFrame: windowFrame)

        XCTAssertEqual(pausedStart, pausedEnd)

        tapPlaybackButton("Resume", in: app)
        scrollToVisible(marquee, in: app, windowFrame: windowFrame, upward: true)
        Thread.sleep(forTimeInterval: 0.2)
        let resumedStart = try croppedScreenshot(of: marquee, windowFrame: windowFrame)
        Thread.sleep(forTimeInterval: 0.3)
        let resumedEnd = try croppedScreenshot(of: marquee, windowFrame: windowFrame)
        XCTAssertNotEqual(resumedStart, resumedEnd)

        tapPlaybackButton("Stop", in: app)
        scrollToVisible(marquee, in: app, windowFrame: windowFrame, upward: true)
        Thread.sleep(forTimeInterval: 0.2)
        let stoppedStart = try croppedScreenshot(of: marquee, windowFrame: windowFrame)
        Thread.sleep(forTimeInterval: 0.3)
        let stoppedEnd = try croppedScreenshot(of: marquee, windowFrame: windowFrame)
        XCTAssertEqual(stoppedStart, stoppedEnd)

        tapPlaybackButton("Start", in: app)
        scrollToVisible(marquee, in: app, windowFrame: windowFrame, upward: true)
        Thread.sleep(forTimeInterval: 1.2)
        let restartedStart = try croppedScreenshot(of: marquee, windowFrame: windowFrame)
        Thread.sleep(forTimeInterval: 0.3)
        let restartedEnd = try croppedScreenshot(of: marquee, windowFrame: windowFrame)
        XCTAssertNotEqual(restartedStart, restartedEnd)
    }

    func testSwiftUIMarqueeTeachesStaticOverflowRichStyledAndRTL() {
        let app = open("Marquee")
        assertSections(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["code.swiftui.marquee.styled"].exists)
        ["Start", "Pause", "Resume", "Stop"].forEach {
            XCTAssertTrue(app.buttons[$0].exists)
        }
    }

    func testSwiftUIPlaybackSnippetUsesDeclarativePublicAPI() {
        let app = open("Marquee")
        let code = app.descendants(matching: .any)[
            "code.swiftui.marquee.playback"
        ]
        XCTAssertTrue(code.exists)
        XCTAssertTrue(code.label.contains("ITextPlaybackState"))
        XCTAssertTrue(code.label.contains("playbackState:"))
        XCTAssertFalse(code.label.contains(".start()"))
        XCTAssertFalse(code.label.contains(".pause()"))
    }

    func testSwiftUICodeSamplesAreSelfContained() {
        let app = open("Marquee")
        let overflow = app.descendants(matching: .any)[
            "code.swiftui.marquee.overflow"
        ]
        let attributed = app.descendants(matching: .any)[
            "code.swiftui.marquee.attributed"
        ]
        let configured = app.descendants(matching: .any)[
            "code.swiftui.marquee.configuration"
        ]

        XCTAssertTrue(overflow.label.contains("This long announcement"))
        XCTAssertTrue(attributed.label.contains("var value = AttributedString"))
        XCTAssertTrue(configured.label.contains("text: \"Configured marquee"))
    }

    func testSwiftUIMarqueePageDoesNotExceedScreenWidth() {
        let app = open("Marquee")
        let window = app.windows.firstMatch.frame

        ["fitting", "overflow", "attributed", "styled", "configuration",
         "rtl", "playback"].forEach { sample in
            let code = app.descendants(matching: .any)[
                "code.swiftui.marquee.\(sample)"
            ]
            XCTAssertTrue(code.exists)
            XCTAssertLessThanOrEqual(
                code.frame.width,
                window.width - 40,
                "\(sample) code frame \(code.frame) exceeds window \(window)"
            )
        }
    }

    func testUIKitMarqueeTeachesInheritedRTLAndPlayback() {
        let app = open("Marquee View", inUIKit: true)
        assertSections(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["code.uikit.marquee.styled"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["marquee.uikit.rtl"].label.contains("مرحبا"))
    }

    private func assertSections(in app: XCUIApplication) {
        ["Fitting text stays static", "Overflowing loop", "Attributed input",
         "Styled input", "Configuration", "Right to left"].forEach {
            XCTAssertTrue(app.staticTexts[$0].exists)
        }
    }

    private func scrollToVisible(
        _ element: XCUIElement,
        in app: XCUIApplication,
        windowFrame: CGRect,
        upward: Bool
    ) {
        for _ in 0..<20 {
            let visibleFrame = element.frame.intersection(windowFrame.insetBy(dx: 0, dy: 60))
            if element.exists, visibleFrame.height >= min(element.frame.height, 20) {
                return
            }
            upward ? app.swipeDown() : app.swipeUp()
        }
        XCTFail("Could not make \(element) visible")
    }

    private func tapPlaybackButton(_ title: String, in app: XCUIApplication) {
        let button = app.buttons[title]
        for _ in 0..<20 where !button.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(button.isHittable)
        button.tap()
    }

    private func croppedScreenshot(
        of element: XCUIElement,
        windowFrame: CGRect
    ) throws -> Data {
        let screenshot = XCUIScreen.main.screenshot()
        let image = try XCTUnwrap(UIImage(data: screenshot.pngRepresentation))
        let cgImage = try XCTUnwrap(image.cgImage)
        let scale = CGFloat(cgImage.width) / windowFrame.width
        let cropRect = element.frame
            .applying(CGAffineTransform(scaleX: scale, y: scale))
            .integral
            .intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        let crop = try XCTUnwrap(cgImage.cropping(to: cropRect))
        return try XCTUnwrap(UIImage(cgImage: crop).pngData())
    }

    private static let overflowText =
        "This long announcement waits, then loops seamlessly when it exceeds the available width."
}
