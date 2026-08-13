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

    func testSwiftUIPlaybackSnippetUsesDeclarativePublicAPI() {
        let app = open("Marquee")
        let code = app.descendants(matching: .any)[
            "code.swiftui.marquee.playback"
        ]
        XCTAssertTrue(code.exists)
        XCTAssertTrue(code.label.contains("ITextPlaybackState"))
        XCTAssertTrue(code.label.contains("playbackState:"))
        XCTAssertFalse(code.label.contains(".start()"))
        XCTAssertFalse(code.label.contains(".pause()"))
    }

    func testSwiftUICodeSamplesAreSelfContained() {
        let app = open("Marquee")
        let overflow = app.descendants(matching: .any)[
            "code.swiftui.marquee.overflow"
        ]
        let attributed = app.descendants(matching: .any)[
            "code.swiftui.marquee.attributed"
        ]
        let configured = app.descendants(matching: .any)[
            "code.swiftui.marquee.configuration"
        ]

        XCTAssertTrue(overflow.label.contains("This long announcement"))
        XCTAssertTrue(attributed.label.contains("var value = AttributedString"))
        XCTAssertTrue(configured.label.contains("text: \"Configured marquee"))
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
