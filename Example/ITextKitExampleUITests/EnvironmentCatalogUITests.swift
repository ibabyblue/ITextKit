import XCTest

final class EnvironmentCatalogUITests: ITextKitExampleUITestCase {
    func testSwiftUIEnvironmentPageUsesHonestSystemStatus() { assertPage(open("Accessibility & Environment"), prefix: "swiftui") }
    func testUIKitEnvironmentPageUsesHonestSystemStatus() { assertPage(open("Accessibility & Environment", inUIKit: true), prefix: "uikit") }
    private func assertPage(_ app: XCUIApplication, prefix: String) {
        ["Left to right", "Right to left", "Dynamic Type", "Reduce Motion", "VoiceOver"].forEach { XCTAssertTrue(app.staticTexts[$0].exists) }
        XCTAssertTrue(app.descendants(matching: .any)["code.\(prefix).environment.rtl"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["code.\(prefix).environment.dynamicType"].exists)
        XCTAssertNotEqual(app.staticTexts["System Reduce Motion: On"].exists, app.staticTexts["System Reduce Motion: Off"].exists)
    }
}
