import XCTest

final class PerformanceFixtureUITests: XCTestCase {
    func testMarqueePerformanceLaunchArgumentShowsSixEagerRows() {
        let app = XCUIApplication()
        app.launchArguments = ["-ITextMarqueePerformance"]
        app.launch()

        XCTAssertTrue(
            app.otherElements["Marquee performance fixture"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertEqual(
            app.descendants(matching: .any).matching(
                NSPredicate(format: "label BEGINSWITH 'Marquee row '")
            ).count,
            6
        )
    }

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
}
