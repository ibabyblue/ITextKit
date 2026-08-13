import XCTest

class ITextKitExampleUITestCase: XCTestCase {
    func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    func open(
        _ title: String,
        inUIKit: Bool = false
    ) -> XCUIApplication {
        let app = launch()
        if inUIKit {
            app.tabBars.buttons["UIKit"].tap()
        }
        let topicID: String
        switch title {
        case "Styled Text", "Styled Label": topicID = "styled"
        case "Rotator", "Rotator View": topicID = "rotator"
        case "Marquee", "Marquee View": topicID = "marquee"
        case "Typewriter", "Typewriter View": topicID = "typewriter"
        case "Shimmer", "Shimmer Label": topicID = "shimmer"
        case "Accessibility & Environment": topicID = "environment"
        default:
            XCTFail("Unknown catalog title: \(title)")
            return app
        }
        let platform = inUIKit ? "uikit" : "swiftui"
        let entry = app.descendants(matching: .any)[
            "catalog.\(platform).\(topicID)"
        ]
        XCTAssertTrue(entry.waitForExistence(timeout: 2))
        XCTAssertEqual(entry.label, title)
        entry.tap()
        return app
    }
}
