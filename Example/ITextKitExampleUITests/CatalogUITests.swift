import XCTest

final class CatalogUITests: ITextKitExampleUITestCase {
    func testSwiftUICatalogExposesSevenTopics() {
        let app = launch()

        XCTAssertTrue(
            app.navigationBars["SwiftUI"].waitForExistence(timeout: 2)
        )
        ["styled", "rotator", "marquee", "typewriter", "shimmer", "environment", "canvas"]
            .forEach {
            let entry = app.descendants(matching: .any)["catalog.swiftui.\($0)"]
            if !entry.exists { app.swipeUp() }
            XCTAssertTrue(
                entry.exists,
                "Missing SwiftUI topic: \($0)"
            )
        }
    }

    func testUIKitCatalogExposesSevenNativeTopics() {
        let app = launch()
        app.tabBars.buttons["UIKit"].tap()

        XCTAssertTrue(
            app.navigationBars["UIKit"].waitForExistence(timeout: 2)
        )
        ["styled", "rotator", "marquee", "typewriter", "shimmer", "environment", "canvas"]
            .forEach {
            let entry = app.descendants(matching: .any)["catalog.uikit.\($0)"]
            if !entry.exists { app.swipeUp() }
            XCTAssertTrue(
                entry.exists,
                "Missing UIKit topic: \($0)"
            )
        }
    }
}
