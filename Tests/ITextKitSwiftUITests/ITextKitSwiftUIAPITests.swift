import SwiftUI
import XCTest
import ITextKit

@MainActor
final class ITextKitSwiftUIAPITests: XCTestCase {
    func testSwiftUIControlsAreAvailableFromSingleModule() {
        let rotator = ITextRotator(
            texts: ["Short", "A longer line that may wrap"],
            configuration: .init(interval: 2, transitionDuration: 0.25),
            playbackState: .paused
        )
        .onTextRotatorChange { _, _ in }

        let marquee = ITextMarquee(
            text: "One long single-line message",
            configuration: .init(speed: 40, spacing: 32, initialDelay: 0.5),
            playbackState: .stopped
        )

        var richRotatorText = AttributedString("Rich rotator")
        richRotatorText.font = .system(size: 24, weight: .bold)
        richRotatorText.foregroundColor = .purple
        richRotatorText.underlineStyle = .single
        let richRotator = ITextRotator(
            attributedTexts: [richRotatorText, AttributedString("Next")],
            playbackState: .paused
        )
        .onTextRotatorChange { _, _ in }

        var richMarqueeText = AttributedString("Rich marquee")
        richMarqueeText.font = .headline
        richMarqueeText.foregroundColor = .blue
        let richMarquee = ITextMarquee(
            attributedText: richMarqueeText,
            playbackState: .stopped
        )

        _ = rotator
        _ = marquee
        _ = richRotator
        _ = richMarquee
    }
}
