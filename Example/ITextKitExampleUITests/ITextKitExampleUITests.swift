import XCTest

final class ITextKitExampleUITests: XCTestCase {
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
}
