import SwiftUI
import UIKit
import XCTest
@testable import ITextKit

@MainActor
final class ITextCanvasSwiftUITests: XCTestCase {
    func testBindingEchoKeepsViewSelectionAndImageResourcesStable() throws {
        let model = CanvasBindingModel()
        model.document = .init(text: "Hello 中文", images: [.init(resourceKey: "one", yOffset: 0.15, widthRatio: 0.2)])
        let host = UIHostingController(rootView: CanvasBindingFixture(model: model))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.layoutIfNeeded()
        let native = try XCTUnwrap(findCanvas(host.view))
        native.textView.selectedRange = NSRange(location: 2, length: 3)
        let loads = model.loads
        host.rootView = CanvasBindingFixture(model: model)
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        XCTAssertTrue(findCanvas(host.view) === native)
        XCTAssertEqual(native.textView.selectedRange, NSRange(location: 2, length: 3))
        XCTAssertEqual(model.loads, loads)
        native.rotateImage(id: model.document.images[0].id, to: 25)
        XCTAssertEqual(model.document.images[0].rotationDegrees, 25, accuracy: 0.01)
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        XCTAssertTrue(native.canUndo, "SwiftUI echo must not clear document history")
        native.undo()
        XCTAssertEqual(model.document.images[0].rotationDegrees, 0, accuracy: 0.01)
    }

    private func findCanvas(_ view: UIView) -> ITextCanvasView? {
        if let canvas = view as? ITextCanvasView { return canvas }
        for child in view.subviews { if let canvas = findCanvas(child) { return canvas } }
        return nil
    }
}

@MainActor
private final class CanvasBindingModel: ObservableObject {
    @Published var document = ITextCanvasDocument()
    var loads = 0
}

private struct CanvasBindingFixture: View {
    @ObservedObject var model: CanvasBindingModel
    var body: some View {
        ITextCanvas(document: $model.document, imageProvider: { _ in model.loads += 1; return nil })
            .frame(height: 500)
    }
}
