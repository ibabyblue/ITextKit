import XCTest

final class CatalogUITests: ITextKitExampleUITestCase {
    func testSwiftUICatalogExposesSixTopics() {
        let app = launch()

        XCTAssertTrue(
            app.navigationBars["SwiftUI"].waitForExistence(timeout: 2)
        )
        ["styled", "rotator", "marquee", "typewriter", "shimmer", "environment"]
            .forEach {
            XCTAssertTrue(
                app.descendants(matching: .any)["catalog.swiftui.\($0)"].exists,
                "Missing SwiftUI topic: \($0)"
            )
        }
    }

    func testUIKitCatalogExposesSixNativeTopics() {
        let app = launch()
        app.tabBars.buttons["UIKit"].tap()

        XCTAssertTrue(
            app.navigationBars["UIKit"].waitForExistence(timeout: 2)
        )
        ["styled", "rotator", "marquee", "typewriter", "shimmer", "environment"]
            .forEach {
            XCTAssertTrue(
                app.descendants(matching: .any)["catalog.uikit.\($0)"].exists,
                "Missing UIKit topic: \($0)"
            )
        }
    }
}
