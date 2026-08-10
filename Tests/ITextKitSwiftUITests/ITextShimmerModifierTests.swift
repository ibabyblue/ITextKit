import SwiftUI
import XCTest
@testable import ITextKit

@MainActor
final class ITextShimmerModifierTests: XCTestCase {
    func testModifierConstructsForPlainAttributedAndMultilineText() {
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
    }
}
