import XCTest
@testable import ITextKit

@MainActor
final class ITextRotatorEngineTests: XCTestCase {
    func testPauseAndResumePreserveRemainingWaitAndTransitionProgress() {
        let engine = makeEngine(interval: 2, transition: 1)
        engine.setEnvironmentActive(true)

        engine.advance(by: 1.5)
        XCTAssertNil(engine.snapshot.nextIndex)

        engine.setPlaybackState(.paused)
        engine.advance(by: 10)
        XCTAssertNil(engine.snapshot.nextIndex)

        engine.setPlaybackState(.playing)
        engine.advance(by: 0.5)
        XCTAssertEqual(engine.snapshot.nextIndex, 1)
        XCTAssertEqual(engine.snapshot.progress, 0, accuracy: 0.000_001)

        engine.advance(by: 0.4)
        XCTAssertEqual(engine.snapshot.progress, 0.4, accuracy: 0.000_001)
        engine.setPlaybackState(.paused)
        let frozen = engine.snapshot
        engine.advance(by: 10)
        XCTAssertEqual(engine.snapshot, frozen)

        engine.setPlaybackState(.playing)
        engine.advance(by: 0.6)
        XCTAssertEqual(engine.snapshot.currentIndex, 1)
        XCTAssertNil(engine.snapshot.nextIndex)
    }

    func testCallbackRunsOnlyAfterSettling() {
        let engine = makeEngine(interval: 1, transition: 0.5)
        var changes: [(Int, String)] = []
        engine.onTextSettled = { changes.append(($0, $1)) }
        engine.setEnvironmentActive(true)

        XCTAssertTrue(changes.isEmpty)
        engine.advance(by: 1.25)
        XCTAssertTrue(changes.isEmpty)
        engine.advance(by: 0.25)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.0, 1)
        XCTAssertEqual(changes.first?.1, "B")
    }

    func testStopDuringTransitionKeepsLastSettledItemAndDiscardsProgress() {
        let engine = makeEngine(interval: 1, transition: 1)
        var callbackCount = 0
        engine.onTextSettled = { _, _ in callbackCount += 1 }
        engine.setEnvironmentActive(true)
        engine.advance(by: 1.5)
        XCTAssertEqual(engine.snapshot.nextIndex, 1)
        XCTAssertEqual(engine.snapshot.progress, 0.5, accuracy: 0.000_001)

        engine.setPlaybackState(.stopped)
        XCTAssertEqual(engine.snapshot.currentIndex, 0)
        XCTAssertNil(engine.snapshot.nextIndex)
        XCTAssertEqual(callbackCount, 0)

        engine.setPlaybackState(.playing)
        engine.advance(by: 0.999)
        XCTAssertNil(engine.snapshot.nextIndex)
        engine.advance(by: 0.002)
        XCTAssertEqual(engine.snapshot.nextIndex, 1)
    }

    func testEnvironmentSuspensionPreservesExactProgress() {
        let engine = makeEngine(interval: 1, transition: 1)
        engine.setEnvironmentActive(true)
        engine.advance(by: 1.3)
        let frozen = engine.snapshot

        engine.setEnvironmentActive(false)
        engine.advance(by: 20)
        XCTAssertEqual(engine.snapshot, frozen)

        engine.setEnvironmentActive(true)
        engine.advance(by: 0.2)
        XCTAssertEqual(engine.snapshot.progress, 0.5, accuracy: 0.000_001)
    }

    func testReplacingTextsResetsToFirstItemAndFullInterval() {
        let engine = makeEngine(interval: 1, transition: 0)
        engine.setEnvironmentActive(true)
        engine.advance(by: 1)
        XCTAssertEqual(engine.snapshot.currentIndex, 1)

        engine.updateTexts(["New", "Next"])
        XCTAssertEqual(engine.snapshot.currentIndex, 0)
        XCTAssertNil(engine.snapshot.nextIndex)
        engine.advance(by: 0.999)
        XCTAssertNil(engine.snapshot.nextIndex)
    }

    func testEmptySingleAndDisabledInputsNeverAdvance() {
        for texts in [[], ["Only"], ["A", "B"]] {
            let configuration = _ITextRotatorResolvedConfiguration(
                interval: texts.count > 1 ? 0 : 1,
                transitionDuration: 0.5
            )
            let engine = _ITextRotatorEngine(
                texts: texts,
                configuration: configuration,
                playbackState: .playing
            )
            engine.setEnvironmentActive(true)
            XCTAssertFalse(engine.shouldAdvance)
            let initial = engine.snapshot
            engine.advance(by: 100)
            XCTAssertEqual(engine.snapshot, initial)
        }
    }

    private func makeEngine(interval: TimeInterval, transition: TimeInterval) -> _ITextRotatorEngine {
        _ITextRotatorEngine(
            texts: ["A", "B", "B"],
            configuration: _ITextRotatorResolvedConfiguration(
                interval: interval,
                transitionDuration: transition
            ),
            playbackState: .playing
        )
    }
}
