import XCTest

final class RotatorCatalogUITests: ITextKitExampleUITestCase {
    func testSwiftUIRotatorTeachesInputsPlaybackAndCallback() {
        let app = open("Rotator")
        assertSections(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["code.swiftui.rotator.styled"].exists)
        ["Start", "Pause", "Resume", "Stop"].forEach {
            XCTAssertTrue(app.buttons[$0].exists)
        }
        XCTAssertTrue(app.staticTexts["Settled index: 0"].exists)
    }

    func testUIKitRotatorTeachesNativePlaybackAndCallback() {
        let app = open("Rotator View", inUIKit: true)
        assertSections(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["code.uikit.rotator.styled"].exists)
        XCTAssertTrue(app.staticTexts["Settled index: 1"].waitForExistence(timeout: 5))
    }

    private func assertSections(in app: XCUIApplication) {
        ["Plain input", "Attributed input", "Styled input", "Variable height"]
            .forEach { XCTAssertTrue(app.staticTexts[$0].exists) }
    }
}
