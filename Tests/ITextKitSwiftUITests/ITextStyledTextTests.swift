import SwiftUI
import UIKit
import XCTest
@testable import ITextKit

@MainActor
final class ITextStyledTextTests: XCTestCase {
    func testPlainAndRichInterfacesConstruct() {
        let style = ITextSwiftUIStyle(
            fill: .linearGradient(.init(colors: [.red, .blue])),
            stroke: .init(paint: .solid(.white), width: 2)
        )

        _ = ITextStyledText(
            "Plain",
            font: .systemFont(ofSize: 24),
            style: style
        )
        _ = ITextStyledText(
            attributedText: NSAttributedString(
                string: "Rich",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                ]
            ),
            style: style
        )
    }

    func testConstrainedWidthWrapsAndReportsGreaterHeight() {
        let view = ITextStyledText(
            "A styled sentence that must wrap across lines",
            font: .systemFont(ofSize: 24),
            style: .init(
                stroke: .init(paint: .solid(.black), width: 2)
            )
        )
        .lineLimit(nil)
        let wide = UIHostingController(rootView: view.frame(width: 300))
        let narrow = UIHostingController(rootView: view.frame(width: 120))

        XCTAssertGreaterThan(
            narrow.sizeThatFits(in: CGSize(width: 120, height: 500)).height,
            wide.sizeThatFits(in: CGSize(width: 300, height: 500)).height
        )
    }

    func testOuterSwiftUIFontDoesNotChangeExplicitUIFontGeometry() {
        let value = ITextStyledText(
            "Explicit UIKit font",
            font: .systemFont(ofSize: 18),
            style: .init(fill: .solid(.red))
        )
        let plain = UIHostingController(rootView: value)
        let decorated = UIHostingController(rootView: value.font(.largeTitle))
        let proposal = CGSize(width: 300, height: 100)

        XCTAssertEqual(
            plain.sizeThatFits(in: proposal),
            decorated.sizeThatFits(in: proposal)
        )
    }

    func testLineLimitAndMultilineAlignmentAreForwardedToLabel() throws {
        let view = ITextStyledText(
            "A long centered sentence that needs truncation",
            font: .systemFont(ofSize: 20),
            style: .init(fill: .solid(.blue))
        )
        .lineLimit(1)
        .multilineTextAlignment(.center)
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()
        host.view.frame = CGRect(x: 0, y: 0, width: 120, height: 80)
        let window = UIWindow(frame: host.view.frame)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        let label = try XCTUnwrap(findStyledLabel(in: host.view))
        XCTAssertEqual(label.numberOfLines, 1)
        XCTAssertEqual(label.textAlignment, .center)
        window.isHidden = true
    }

    private func findStyledLabel(in view: UIView) -> ITextStyledLabel? {
        if let label = view as? ITextStyledLabel { return label }
        return view.subviews.lazy.compactMap(findStyledLabel(in:)).first
    }
}
