import XCTest

final class ITextKitExampleUITests: XCTestCase {
    func testSwiftUIRotatorMovesFromShortToTallerText() {
        let app = XCUIApplication()
        app.launch()

        let shortText = app.staticTexts["A short message"]
        XCTAssertTrue(shortText.waitForExistence(timeout: 2))
        let shortHeight = shortText.frame.height
        XCTAssertTrue(app.buttons["Start"].exists)
        XCTAssertTrue(app.buttons["Pause"].exists)
        XCTAssertTrue(app.buttons["Resume"].exists)
        XCTAssertTrue(app.buttons["Stop"].exists)

        app.buttons["Pause"].tap()
        app.buttons["Resume"].tap()

        let longText = app.staticTexts[
            "The rotator grows while this longer message wraps naturally across multiple lines."
        ]
        XCTAssertTrue(longText.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(longText.frame.height, shortHeight)

        keepScreenshot(of: app, named: "SwiftUI Example")
    }

    func testUIKitTabContainsNativeControls() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["UIKit"].tap()

        XCTAssertTrue(app.staticTexts["Variable-height rotator"].waitForExistence(timeout: 2))
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
    }

    private func keepScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
