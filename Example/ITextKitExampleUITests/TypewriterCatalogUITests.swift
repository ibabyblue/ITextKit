import XCTest

final class TypewriterCatalogUITests: ITextKitExampleUITestCase {
    func testSwiftUITypewriterTeachesSupportedBehaviorOnly() {
        let app = open("Typewriter"); assertSections(in: app)
        XCTAssertFalse(app.buttons["Pause"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["code.swiftui.typewriter.styled"].exists)
        XCTAssertTrue(app.buttons["Replay Typewriter"].exists)
    }
    func testUIKitTypewriterTeachesAutoLayoutAndReplay() {
        let app = open("Typewriter View", inUIKit: true); assertSections(in: app)
        XCTAssertFalse(app.buttons["Pause"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["code.uikit.typewriter.styled"].exists)
        XCTAssertTrue(app.buttons["Replay Typewriter"].exists)
    }
    private func assertSections(in app: XCUIApplication) {
        ["Plain input", "Attributed input", "Styled input", "Wrapping and growth", "Emoji stays whole"].forEach { XCTAssertTrue(app.staticTexts[$0].exists) }
    }
}
