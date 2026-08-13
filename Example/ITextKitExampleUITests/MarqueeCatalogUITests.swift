import XCTest

final class MarqueeCatalogUITests: ITextKitExampleUITestCase {
    func testSwiftUIMarqueeTeachesStaticOverflowRichStyledAndRTL() {
        let app = open("Marquee")
        assertSections(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["code.swiftui.marquee.styled"].exists)
        ["Start", "Pause", "Resume", "Stop"].forEach {
            XCTAssertTrue(app.buttons[$0].exists)
        }
    }

    func testUIKitMarqueeTeachesInheritedRTLAndPlayback() {
        let app = open("Marquee View", inUIKit: true)
        assertSections(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["code.uikit.marquee.styled"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["marquee.uikit.rtl"].label.contains("مرحبا"))
    }

    private func assertSections(in app: XCUIApplication) {
        ["Fitting text stays static", "Overflowing loop", "Attributed input",
         "Styled input", "Configuration", "Right to left"].forEach {
            XCTAssertTrue(app.staticTexts[$0].exists)
        }
    }
}
