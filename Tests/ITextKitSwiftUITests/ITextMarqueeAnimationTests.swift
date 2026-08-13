import SwiftUI
import XCTest
@testable import ITextKit

@MainActor
final class ITextMarqueeAnimationTests: XCTestCase {
    func testInitialOverflowPublishesLeadingBeforeStartingTravel() async {
        let gate = TestGate()
        let model = _ITextMarqueeObservable(
            attributedText: AttributedString("A long native SwiftUI marquee"),
            configuration: .init(speed: 40, spacing: 20, initialDelay: 0),
            playbackState: .playing,
            sleeper: { _ in
                await gate.wait()
            }
        )

        model.updateContentWidth(200)
        model.updateViewportWidth(80)
        model.setVisible(true, sceneIsActive: true)

        XCTAssertEqual(model.transition.targetOffset, 0)
        XCTAssertEqual(model.transition.duration, 0)
        XCTAssertFalse(model.transition.repeats)

        gate.open()
        for _ in 0..<10 where model.transition.targetOffset == 0 {
            await Task.yield()
        }

        XCTAssertEqual(model.transition.targetOffset, 220)
        XCTAssertEqual(model.transition.duration, 5.5, accuracy: 0.000_001)
        XCTAssertTrue(model.transition.repeats)
    }

    func testTravelPublishesOnlyAtDiscreteStateTransitions() async {
        let clock = TestClock()
        let model = _ITextMarqueeObservable(
            attributedText: AttributedString("A long native SwiftUI marquee"),
            configuration: .init(speed: 40, spacing: 20, initialDelay: 0),
            playbackState: .playing,
            now: { clock.time },
            sleeper: { duration in
                if duration == 0 {
                    await Task.yield()
                } else {
                    try await Task.sleep(nanoseconds: 1_000_000_000_000)
                }
            }
        )

        model.updateContentWidth(200)
        model.updateViewportWidth(80)
        model.setVisible(true, sceneIsActive: true)
        for _ in 0..<10 where model.transition.targetOffset == 0 {
            await Task.yield()
        }

        XCTAssertEqual(model.transition.targetOffset, 220)
        XCTAssertEqual(model.transition.duration, 5.5, accuracy: 0.000_001)
        XCTAssertEqual(model.transition.delay, 0)
        XCTAssertTrue(model.transition.repeats)
        XCTAssertNil(Mirror(reflecting: model).descendant("displayLink"))
        let runningPublication = model._publicationGeneration

        clock.time += 0.25
        XCTAssertEqual(model._publicationGeneration, runningPublication)

        model.setPlaybackState(.paused)
        XCTAssertEqual(model.transition.targetOffset, 10, accuracy: 0.000_001)
        XCTAssertEqual(model.transition.duration, 0)
        XCTAssertFalse(model.transition.repeats)
        XCTAssertEqual(model._publicationGeneration, runningPublication + 1)

        model.setPlaybackState(.playing)
        XCTAssertEqual(model.transition.targetOffset, 220)
        XCTAssertEqual(model.transition.duration, 5.25, accuracy: 0.000_001)
        XCTAssertFalse(model.transition.repeats)
        XCTAssertEqual(model._publicationGeneration, runningPublication + 2)
    }

    func testSceneFreezePublishesStaticPhaseWithoutChangingCallerState() {
        let clock = TestClock()
        let model = _ITextMarqueeObservable(
            attributedText: AttributedString("A long native SwiftUI marquee"),
            configuration: .init(speed: 40, spacing: 20, initialDelay: 1),
            playbackState: .playing,
            now: { clock.time },
            sleeper: { _ in
                try await Task.sleep(nanoseconds: 1_000_000_000_000)
            }
        )
        model.updateContentWidth(200)
        model.updateViewportWidth(80)
        model.setVisible(true, sceneIsActive: true)
        clock.time += 1.25

        model.setSceneActive(false)

        XCTAssertEqual(model.snapshot.playbackState, .playing)
        XCTAssertEqual(model.transition.targetOffset, 10, accuracy: 0.000_001)
        XCTAssertEqual(model.transition.duration, 0)
        XCTAssertFalse(model.transition.repeats)
    }

    private final class TestClock {
        var time: CFTimeInterval = 0
    }

    @MainActor
    private final class TestGate {
        private var isOpen = false
        private var continuation: CheckedContinuation<Void, Never>?

        func wait() async {
            guard !isOpen else { return }
            await withCheckedContinuation { continuation = $0 }
        }

        func open() {
            isOpen = true
            continuation?.resume()
            continuation = nil
        }
    }
}
