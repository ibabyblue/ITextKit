import XCTest

final class PerformanceFixtureUITests: XCTestCase {
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
