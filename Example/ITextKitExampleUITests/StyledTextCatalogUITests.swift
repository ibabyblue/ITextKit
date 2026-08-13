import XCTest

final class StyledTextCatalogUITests: ITextKitExampleUITestCase {
    func testSwiftUIStyledPageShowsCompleteMatrixAndCopyableCode() {
        let app = open("Styled Text")

        assertVisibleText([
            "Native reference",
            "Gradient fill",
            "0.5 pt",
            "1 pt",
            "2 pt",
            "3 pt",
            "Gradient stroke",
            "Fill + stroke",
            "Attributed",
            "Multiline gradient",
            "Semantic RTL",
            "Physical unit points",
            "Styled shimmer"
        ], in: app)

        let code = app.descendants(matching: .any)[
            "code.swiftui.styled.combined"
        ]
        XCTAssertTrue(code.exists)
        XCTAssertTrue(code.label.contains("ITextStyledText"))
        XCTAssertTrue(code.label.contains(".shimmerText()"))

        let copy = app.buttons["copy.swiftui.styled.combined"]
        reveal(copy, in: app)
        copy.tap()
        XCTAssertEqual(copy.label, "Copied")
    }

    func testUIKitStyledPageShowsCompleteMatrixAndSizingNotes() {
        let app = open("Styled Label", inUIKit: true)

        assertVisibleText([
            "Native UILabel reference",
            "Gradient fill",
            "0.5 pt",
            "1 pt",
            "2 pt",
            "3 pt",
            "Gradient stroke",
            "Fill + stroke",
            "Attributed",
            "Multiline gradient",
            "Intrinsic size",
            "Auto Layout",
            "Semantic RTL"
        ], in: app)

        let code = app.descendants(matching: .any)[
            "code.uikit.styled.combined"
        ]
        XCTAssertTrue(code.exists)
        XCTAssertTrue(code.label.contains("ITextStyledLabel"))
        XCTAssertTrue(code.label.contains("width: 2"))
    }

    private func assertVisibleText(
        _ labels: [String],
        in app: XCUIApplication
    ) {
        labels.forEach {
            XCTAssertTrue(app.staticTexts[$0].exists, "Missing example: \($0)")
        }
    }
}
