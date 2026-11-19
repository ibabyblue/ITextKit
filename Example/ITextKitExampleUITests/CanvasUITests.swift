import XCTest

final class CanvasUITests: XCTestCase {
    private let imageID = "ITextCanvas.image.52E70000-0000-0000-0000-000000000001"

    func testNativeDragRotateUndoAndRestore() {
        let app = launch()
        let image = app.descendants(matching: .any)[imageID].firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        let original = image.frame
        let start = image.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.5, thenDragTo: start.withOffset(CGVector(dx: 35, dy: 60)))
        let moved = image.frame
        XCTAssertGreaterThan(moved.midY - original.midY, 30)
        XCTAssertTrue(app.staticTexts["canvas.status"].label.contains("edits 1"))
        app.buttons["canvas.save"].tap()
        let originalAngle = image.value as? String
        image.rotate(.pi / 5, withVelocity: 1)
        XCTAssertNotEqual(image.value as? String, originalAngle)
        XCTAssertTrue(app.staticTexts["canvas.status"].label.contains("edits 2"))
        app.buttons["canvas.undo"].tap()
        XCTAssertEqual(image.value as? String, originalAngle)
        app.buttons["canvas.redo"].tap()
        XCTAssertNotEqual(image.value as? String, originalAngle)
        app.buttons["canvas.restore"].tap()
        XCTAssertEqual(image.value as? String, originalAngle)
        XCTAssertEqual(image.frame.midY, moved.midY, accuracy: 2)
        attach(app, name: "UIKit rotated-image wrapping")
        app.buttons["canvas.mode"].tap()
        let readonly = image.frame
        let readonlyStart = image.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        readonlyStart.press(forDuration: 0.5, thenDragTo: readonlyStart.withOffset(CGVector(dx: 0, dy: 40)))
        XCTAssertEqual(image.frame.midY, readonly.midY, accuracy: 2)
    }

    func testSwiftUIRotationBindingAndTextEditing() {
        let app = launch(swiftUI: true)
        let image = app.descendants(matching: .any)[imageID].firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        let angle = image.value as? String
        image.rotate(.pi / 6, withVelocity: 1)
        XCTAssertNotEqual(image.value as? String, angle)
        let editor = app.textViews["ITextCanvas.text"]
        XCTAssertTrue(editor.exists)
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.1)).tap()
        editor.typeText(" Canvas input")
        XCTAssertTrue((editor.value as? String ?? "").contains("Canvas input"))
        attach(app, name: "SwiftUI canvas input and rotation")
    }

    private func launch(swiftUI: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [swiftUI ? "-ITextCanvasSwiftUIExample" : "-ITextCanvasExample"]
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
