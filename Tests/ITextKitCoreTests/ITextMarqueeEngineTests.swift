import XCTest
@testable import ITextKit

@MainActor
final class ITextMarqueeEngineTests: XCTestCase {
    func testInitialDelaySpeedAndSeamlessWrap() {
        let engine = makeEngine(speed: 10, spacing: 20, delay: 1)
        engine.updateMetrics(contentWidth: 100, viewportWidth: 50)
        engine.setEnvironmentActive(true)

        engine.advance(by: 0.75)
        XCTAssertEqual(engine.snapshot.offset, 0)
        engine.advance(by: 0.75)
        XCTAssertEqual(engine.snapshot.offset, 5, accuracy: 0.000_001)

        engine.advance(by: 12)
        XCTAssertEqual(engine.snapshot.offset, 5, accuracy: 0.000_001)
    }

    func testPauseResumeAndLifecyclePreserveExactOffset() {
        let engine = makeEngine(speed: 20, spacing: 10, delay: 0)
        engine.updateMetrics(contentWidth: 80, viewportWidth: 40)
        engine.setEnvironmentActive(true)
        engine.advance(by: 0.5)
        XCTAssertEqual(engine.snapshot.offset, 10, accuracy: 0.000_001)

        engine.setPlaybackState(.paused)
        engine.advance(by: 50)
        XCTAssertEqual(engine.snapshot.offset, 10, accuracy: 0.000_001)
        engine.setPlaybackState(.playing)
        engine.advance(by: 0.25)
        XCTAssertEqual(engine.snapshot.offset, 15, accuracy: 0.000_001)

        engine.setEnvironmentActive(false)
        engine.advance(by: 50)
        XCTAssertEqual(engine.snapshot.offset, 15, accuracy: 0.000_001)
        engine.setEnvironmentActive(true)
        engine.advance(by: 0.25)
        XCTAssertEqual(engine.snapshot.offset, 20, accuracy: 0.000_001)
    }

    func testStopAndRestartReturnToLeadingWithFullDelay() {
        let engine = makeEngine(speed: 10, spacing: 20, delay: 1)
        engine.updateMetrics(contentWidth: 100, viewportWidth: 50)
        engine.setEnvironmentActive(true)
        engine.advance(by: 2)
        XCTAssertEqual(engine.snapshot.offset, 10, accuracy: 0.000_001)

        engine.setPlaybackState(.stopped)
        XCTAssertEqual(engine.snapshot.offset, 0)
        engine.setPlaybackState(.playing)
        engine.advance(by: 0.9)
        XCTAssertEqual(engine.snapshot.offset, 0)
        engine.advance(by: 0.2)
        XCTAssertEqual(engine.snapshot.offset, 1, accuracy: 0.000_001)
    }

    func testMetricAndConfigurationChangesRestartMotion() {
        let engine = makeEngine(speed: 10, spacing: 20, delay: 0)
        engine.updateMetrics(contentWidth: 100, viewportWidth: 50)
        engine.setEnvironmentActive(true)
        engine.advance(by: 1)
        XCTAssertEqual(engine.snapshot.offset, 10, accuracy: 0.000_001)

        engine.updateMetrics(contentWidth: 110, viewportWidth: 50)
        XCTAssertEqual(engine.snapshot.offset, 0)
        engine.advance(by: 1)
        XCTAssertEqual(engine.snapshot.offset, 10, accuracy: 0.000_001)

        engine.updateConfiguration(.init(speed: 20, spacing: 10, initialDelay: 0.5))
        XCTAssertEqual(engine.snapshot.offset, 0)
        engine.advance(by: 0.5)
        XCTAssertEqual(engine.snapshot.offset, 0)
    }

    func testFittingTextZeroSpeedAndReduceMotionRemainStatic() {
        let engine = makeEngine(speed: 10, spacing: 20, delay: 0)
        engine.updateMetrics(contentWidth: 40, viewportWidth: 50)
        engine.setEnvironmentActive(true)
        XCTAssertFalse(engine.shouldAdvance)

        engine.updateMetrics(contentWidth: 100, viewportWidth: 50)
        engine.setMotionAllowed(false)
        XCTAssertFalse(engine.shouldAdvance)
        engine.advance(by: 10)
        XCTAssertEqual(engine.snapshot.offset, 0)

        engine.setMotionAllowed(true)
        engine.updateConfiguration(.init(speed: 0, spacing: 20, initialDelay: 0))
        XCTAssertFalse(engine.shouldAdvance)
    }

    private func makeEngine(
        speed: CGFloat,
        spacing: CGFloat,
        delay: TimeInterval
    ) -> _ITextMarqueeEngine {
        _ITextMarqueeEngine(
            configuration: .init(speed: speed, spacing: spacing, initialDelay: delay),
            playbackState: .playing
        )
    }
}
