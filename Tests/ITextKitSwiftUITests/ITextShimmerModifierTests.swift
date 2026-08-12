import SwiftUI
import XCTest
@testable import ITextKit

@MainActor
final class ITextShimmerModifierTests: XCTestCase {
    func testModifierConstructsForPlainAttributedAndMultilineText() {
        let styled = ITextStyledText(
            "Working…",
            font: .systemFont(ofSize: 28, weight: .bold),
            style: .init(
                fill: .linearGradient(.init(colors: [.blue, .purple])),
                stroke: .init(paint: .solid(.black), width: 2)
            )
        )
        .shimmerText(highlight: .white)
        let plain = Text("Working…")
            .foregroundStyle(.secondary)
            .shimmerText()

        var attributed = AttributedString("Rich shimmer")
        attributed.font = .headline.bold()
        attributed.foregroundColor = .purple
        let rich = Text(attributed)
            .shimmerText(
                isActive: true,
                configuration: .init(
                    duration: 2,
                    bandWidth: 0.4,
                    intensity: 0.7,
                    direction: .trailingToLeading
                ),
                highlight: .primary
            )

        let multiline = Text("A longer status\nthat spans lines")
            .lineLimit(nil)
            .shimmerText(isActive: false)

        _ = plain
        _ = rich
        _ = multiline
        _ = styled
    }
}
