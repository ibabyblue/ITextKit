import SwiftUI
import XCTest
@testable import ITextKit

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

        let typewriter = ITextTypewriter(
            text: "Plain typewriter",
            configuration: .init(charactersPerSecond: 24, initialDelay: 0.2)
        )

        var richTypewriterText = AttributedString("Rich 👨‍👩‍👧‍👦 typewriter")
        richTypewriterText.font = .headline.bold()
        richTypewriterText.foregroundColor = .green
        let richTypewriter = ITextTypewriter(
            attributedText: richTypewriterText
        )

        _ = rotator
        _ = marquee
        _ = richRotator
        _ = richMarquee
        _ = typewriter
        _ = richTypewriter
    }

    func testTypewriterAdapterPreservesRichCharacterBoundariesAndLifecycleProgress() throws {
        let family = "👨‍👩‍👧‍👦"
        var richText = AttributedString(family + "A")
        richText.foregroundColor = .purple
        richText.underlineStyle = .single
        let model = _ITextTypewriterObservable(
            attributedText: richText,
            configuration: .init(charactersPerSecond: 0.01, initialDelay: 0)
        )
        let engine = try XCTUnwrap(
            Mirror(reflecting: model).descendant("engine") as? _ITextTypewriterEngine
        )

        XCTAssertEqual(model.snapshot.revealedCount, 0)
        model.setVisible(true, sceneIsActive: true)
        XCTAssertEqual(model.snapshot.revealedCount, 1)

        let firstEnd = richText.characters.index(after: richText.startIndex)
        XCTAssertEqual(
            model.visibleAttributedText,
            AttributedString(richText[..<firstEnd])
        )

        engine.advance(by: 40)
        model.setVisible(false, sceneIsActive: false)
        engine.advance(by: 100)
        XCTAssertEqual(model.snapshot.revealedCount, 1)

        model.setVisible(true, sceneIsActive: true)
        engine.advance(by: 61)
        XCTAssertEqual(model.snapshot.revealedCount, 2)
        XCTAssertEqual(model.visibleAttributedText, richText)

        model.setVisible(false, sceneIsActive: false)
    }

    func testTypewriterAdapterIgnoresEqualContentAndCompletesForReduceMotion() throws {
        var richText = AttributedString("ABC")
        richText.foregroundColor = .green
        let model = _ITextTypewriterObservable(
            attributedText: richText,
            configuration: .init(charactersPerSecond: 0.01, initialDelay: 0)
        )
        let engine = try XCTUnwrap(
            Mirror(reflecting: model).descendant("engine") as? _ITextTypewriterEngine
        )
        model.setVisible(true, sceneIsActive: true)
        engine.advance(by: 100)
        XCTAssertEqual(model.snapshot.revealedCount, 2)

        model.updateAttributedText(richText)
        XCTAssertEqual(model.snapshot.revealedCount, 2)

        richText.foregroundColor = .orange
        model.updateAttributedText(richText)
        XCTAssertEqual(model.snapshot.revealedCount, 1)

        model.setMotionAllowed(false)
        XCTAssertEqual(model.snapshot.revealedCount, 3)
        model.setMotionAllowed(true)
        XCTAssertEqual(model.snapshot.revealedCount, 3)

        model.setVisible(false, sceneIsActive: false)
    }

}
