import SwiftUI
import UIKit
import XCTest
@testable import ITextKit

@MainActor
final class ITextKitSwiftUIAPITests: XCTestCase {
    func testSwiftUIControlsAreAvailableFromSingleModule() {
        _ = ITextStyledText(
            "Styled",
            font: .systemFont(ofSize: 20),
            style: .init(
                fill: .linearGradient(.init(colors: [.pink, .orange])),
                stroke: .init(paint: .solid(.black), width: 1.5)
            )
        )
        let style = ITextSwiftUIStyle(
            fill: .linearGradient(.init(colors: [.pink, .orange])),
            stroke: .init(paint: .solid(.black), width: 1.5)
        )
        _ = ITextRotator(
            texts: ["First", "Second"],
            textStyle: style,
            playbackState: .paused
        )
        _ = ITextRotator(
            styledAttributedTexts: [NSAttributedString(string: "Rich")],
            textStyle: style,
            playbackState: .paused
        )
        _ = ITextMarquee(
            text: "Styled marquee",
            textStyle: style,
            playbackState: .paused
        )
        _ = ITextMarquee(
            styledAttributedText: NSAttributedString(string: "Rich marquee"),
            textStyle: style,
            playbackState: .paused
        )
        _ = ITextTypewriter(text: "Styled typing", textStyle: style)
        _ = ITextTypewriter(
            styledAttributedText: NSAttributedString(string: "Rich typing"),
            textStyle: style
        )

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

    func testStyledMarqueeUsesProposedViewportAndOverflows() throws {
        let value = ITextMarquee(
            text: "A long outlined marquee must move inside this narrow SwiftUI viewport",
            font: .systemFont(ofSize: 20, weight: .bold),
            textStyle: .init(
                fill: .linearGradient(.init(colors: [.pink, .orange])),
                stroke: .init(paint: .solid(.blue), width: 1)
            ),
            configuration: .init(speed: 40, spacing: 24, initialDelay: 0),
            playbackState: .paused
        )
        .frame(width: 180)

        let host = UIHostingController(rootView: value)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let marquee = try XCTUnwrap(
            findSubview(of: ITextMarqueeView.self, in: host.view)
        )
        XCTAssertEqual(marquee.bounds.width, 180, accuracy: 0.5)

        let engine = try XCTUnwrap(
            Mirror(reflecting: marquee).descendant("engine") as? _ITextMarqueeEngine
        )
        XCTAssertTrue(engine.snapshot.isOverflowing)
        marquee.resume()
        engine.setEnvironmentActive(true)
        marquee.layoutIfNeeded()
        XCTAssertTrue(marquee._hasActiveTravelAnimation)
    }

    func testStyledMarqueeEqualSwiftUIUpdateKeepsRenderedCopiesStable() throws {
        let value = ITextMarquee(
            text: "A long gradient outlined marquee for stable representable updates",
            font: .systemFont(ofSize: 20, weight: .bold),
            textStyle: .init(
                fill: .linearGradient(.init(colors: [.pink, .orange])),
                stroke: .init(
                    paint: .linearGradient(.init(colors: [.white, .blue])),
                    width: 1
                )
            ),
            configuration: .init(speed: 40, spacing: 24, initialDelay: 0),
            playbackState: .playing
        )
        .frame(width: 180)
        let host = UIHostingController(rootView: value)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        let marquee = try XCTUnwrap(findSubview(of: ITextMarqueeView.self, in: host.view))
        marquee._movingLabels.forEach { $0.layer.displayIfNeeded() }
        let measurement = marquee._measurementGeneration
        let layout = marquee._movingLabels.map(\._layoutGeneration)
        let drawing = marquee._movingLabels.map(\._drawingGeneration)

        host.rootView = value
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        let updated = try XCTUnwrap(findSubview(of: ITextMarqueeView.self, in: host.view))
        updated._movingLabels.forEach { $0.layer.displayIfNeeded() }

        XCTAssertTrue(updated === marquee)
        XCTAssertEqual(updated._measurementGeneration, measurement)
        XCTAssertEqual(updated._movingLabels.map(\._layoutGeneration), layout)
        XCTAssertEqual(updated._movingLabels.map(\._drawingGeneration), drawing)
        XCTAssertTrue(updated._hasActiveTravelAnimation)
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

    private func findSubview<T: UIView>(
        of type: T.Type,
        in root: UIView
    ) -> T? {
        if let match = root as? T { return match }
        for child in root.subviews {
            if let match = findSubview(of: type, in: child) {
                return match
            }
        }
        return nil
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

    func testMountedRotatorUsesLatestChangeCallback() {
        let state = ITextRotatorCallbackTestState()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        let host = UIHostingController(rootView: ITextRotatorCallbackTestView(state: state))
        window.rootViewController = host
        window.makeKeyAndVisible()

        let callbackDeadline = Date().addingTimeInterval(2)
        while state.firstCallbackCount == 0, Date() < callbackDeadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertGreaterThan(state.firstCallbackCount, 0)

        state.usesSecondCallback = true
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let firstCountAfterUpdate = state.firstCallbackCount
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        XCTAssertEqual(state.firstCallbackCount, firstCountAfterUpdate)
        XCTAssertGreaterThan(state.secondCallbackCount, 0)
        window.isHidden = true
    }

}

@MainActor
private final class ITextRotatorCallbackTestState: ObservableObject {
    @Published var usesSecondCallback = false
    var firstCallbackCount = 0
    var secondCallbackCount = 0
}

@MainActor
private struct ITextRotatorCallbackTestView: View {
    @ObservedObject var state: ITextRotatorCallbackTestState

    var body: some View {
        let usesSecondCallback = state.usesSecondCallback
        ITextRotator(
            texts: ["First", "Second"],
            configuration: .init(interval: 0.03, transitionDuration: 0)
        )
        .onTextRotatorChange { _, _ in
            if usesSecondCallback {
                state.secondCallbackCount += 1
            } else {
                state.firstCallbackCount += 1
            }
        }
        .environment(\.scenePhase, .active)
    }
}
