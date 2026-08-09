import UIKit
import XCTest
@testable import ITextKit

@MainActor
final class ITextKitUIKitAPITests: XCTestCase {
    func testRotatorMovesOutgoingTextUpAndIncomingTextFromBelowWhileCrossFading() throws {
        let view = ITextRotatorView(
            texts: ["First", "Second"],
            configuration: ITextRotatorConfiguration(
                interval: 1,
                transitionDuration: 1
            ),
            playbackState: .paused
        )
        view.frame = CGRect(x: 0, y: 0, width: 160, height: 40)

        let engine = try XCTUnwrap(
            Mirror(reflecting: view).descendant("engine") as? _ITextRotatorEngine
        )
        engine.setEnvironmentActive(true)
        engine.setPlaybackState(.playing)
        let labels = view.subviews.compactMap { $0 as? UILabel }
        XCTAssertEqual(labels.count, 2)
        engine.advance(by: 1)

        for step in 1...3 {
            engine.advance(by: 0.25)
            view.layoutIfNeeded()
            let presentation = _ITextRotatorTransitionPresentation(
                linearProgress: Double(step) * 0.25,
                reduceMotion: UIAccessibility.isReduceMotionEnabled
            )

            XCTAssertEqual(labels[0].text, "First")
            XCTAssertEqual(labels[1].text, "Second")
            XCTAssertEqual(
                labels[0].alpha,
                presentation.outgoing.opacity,
                accuracy: 0.01
            )
            XCTAssertEqual(
                labels[1].alpha,
                presentation.incoming.opacity,
                accuracy: 0.01
            )

            if !UIAccessibility.isReduceMotionEnabled {
                XCTAssertEqual(
                    -labels[0].frame.minY / labels[0].bounds.height,
                    -presentation.outgoing.verticalOffsetFactor,
                    accuracy: 0.02
                )
                XCTAssertEqual(
                    labels[1].frame.minY / labels[1].bounds.height,
                    presentation.incoming.verticalOffsetFactor,
                    accuracy: 0.02
                )
            }
        }

        engine.setPlaybackState(.paused)
    }

    func testRotatorPublicStylePlaybackAndAccessibility() {
        let view = ITextRotatorView(
            texts: ["First", "A much longer second line that wraps"],
            playbackState: .paused
        )
        view.font = .preferredFont(forTextStyle: .headline)
        view.textColor = .systemPurple
        view.textAlignment = .center
        view.numberOfLines = 0
        view.frame = CGRect(x: 0, y: 0, width: 120, height: 80)
        view.layoutIfNeeded()

        XCTAssertEqual(view.playbackState, .paused)
        XCTAssertEqual(view.accessibilityLabel, "First")
        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertEqual(view.subviews.count, 2)
        XCTAssertTrue(view.subviews.allSatisfy { !$0.isAccessibilityElement })
        XCTAssertGreaterThan(view.intrinsicContentSize.height, 0)
        view.resume()
        XCTAssertEqual(view.playbackState, .playing)
        view.pause()
        view.start()
        XCTAssertEqual(view.playbackState, .playing)
        view.stop()
        XCTAssertEqual(view.playbackState, .stopped)
    }

    func testMarqueePublicStylePlaybackAndAccessibility() {
        let view = ITextMarqueeView(
            text: "A long marquee line that should overflow this narrow viewport",
            playbackState: .paused
        )
        view.font = .preferredFont(forTextStyle: .body)
        view.textColor = .systemBlue
        view.textAlignment = .natural
        view.frame = CGRect(x: 0, y: 0, width: 80, height: 30)
        view.layoutIfNeeded()

        XCTAssertEqual(view.playbackState, .paused)
        XCTAssertEqual(view.accessibilityLabel, view.text)
        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertEqual(view.subviews.count, 2)
        XCTAssertTrue(view.subviews.allSatisfy { !$0.isAccessibilityElement })
        XCTAssertGreaterThan(view.intrinsicContentSize.height, 0)
        let labels = view.subviews.compactMap { $0 as? UILabel }
        XCTAssertEqual(labels.map(\.text), [view.text, view.text])
        XCTAssertTrue(labels.contains { label in
            !label.isHidden && label.frame.intersects(view.bounds)
        })

        view.resume()
        XCTAssertEqual(view.playbackState, .playing)
        view.pause()
        view.start()
        XCTAssertEqual(view.playbackState, .playing)
        view.stop()
        XCTAssertEqual(view.playbackState, .stopped)
    }
}
