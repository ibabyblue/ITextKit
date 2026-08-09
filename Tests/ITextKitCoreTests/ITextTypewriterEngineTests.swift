import XCTest
@testable import ITextKit

@MainActor
final class ITextTypewriterEngineTests: XCTestCase {
    func testFirstUnitAppearsImmediatelyThenUsesConfiguredSpeed() {
        let engine = makeEngine(unitCount: 5, speed: 2, delay: 0)

        XCTAssertEqual(engine.snapshot.revealedCount, 0)
        engine.setEnvironmentActive(true)
        XCTAssertEqual(engine.snapshot.revealedCount, 1)

        engine.advance(by: 0.49)
        XCTAssertEqual(engine.snapshot.revealedCount, 1)
        engine.advance(by: 0.01)
        XCTAssertEqual(engine.snapshot.revealedCount, 2)
    }

    func testInitialDelayEndsWithImmediateFirstUnitAndRetainsRemainder() {
        let engine = makeEngine(unitCount: 5, speed: 2, delay: 1)
        engine.setEnvironmentActive(true)

        engine.advance(by: 0.75)
        XCTAssertEqual(engine.snapshot.revealedCount, 0)
        engine.advance(by: 0.5)
        XCTAssertEqual(engine.snapshot.revealedCount, 1)
        engine.advance(by: 0.25)
        XCTAssertEqual(engine.snapshot.revealedCount, 2)
    }

    func testLongFrameCatchesUpMultipleUnitsAndStopsAtCompletion() {
        let engine = makeEngine(unitCount: 5, speed: 10, delay: 0)
        engine.setEnvironmentActive(true)

        engine.advance(by: 0.35)
        XCTAssertEqual(engine.snapshot.revealedCount, 4)
        engine.advance(by: 10)
        XCTAssertEqual(engine.snapshot.revealedCount, 5)
        XCTAssertTrue(engine.snapshot.isComplete)
        XCTAssertFalse(engine.shouldAdvance)
    }

    func testExtremelyHighFiniteSpeedCompletesWithoutIntegerOverflow() {
        let engine = makeEngine(
            unitCount: 5,
            speed: Double.greatestFiniteMagnitude,
            delay: 0
        )
        engine.setEnvironmentActive(true)

        engine.advance(by: 0.001)

        XCTAssertEqual(engine.snapshot.revealedCount, 5)
        XCTAssertFalse(engine.shouldAdvance)
    }

    func testLifecycleSuspensionPreservesFractionalProgress() {
        let engine = makeEngine(unitCount: 4, speed: 2, delay: 0)
        engine.setEnvironmentActive(true)
        engine.advance(by: 0.3)

        engine.setEnvironmentActive(false)
        engine.advance(by: 10)
        XCTAssertEqual(engine.snapshot.revealedCount, 1)

        engine.setEnvironmentActive(true)
        engine.advance(by: 0.2)
        XCTAssertEqual(engine.snapshot.revealedCount, 2)
    }

    func testContentAndConfigurationChangesRestart() {
        let engine = makeEngine(unitCount: 4, speed: 4, delay: 0)
        engine.setEnvironmentActive(true)
        engine.advance(by: 0.5)
        XCTAssertEqual(engine.snapshot.revealedCount, 3)

        engine.updateUnitCount(2)
        XCTAssertEqual(engine.snapshot.revealedCount, 1)
        XCTAssertEqual(engine.snapshot.unitCount, 2)

        engine.updateConfiguration(.init(charactersPerSecond: 2, initialDelay: 1))
        XCTAssertEqual(engine.snapshot.revealedCount, 0)
        engine.advance(by: 1)
        XCTAssertEqual(engine.snapshot.revealedCount, 1)
    }

    func testReduceMotionRevealsAllAndNeverReplaysWhenReenabled() {
        let engine = makeEngine(unitCount: 5, speed: 2, delay: 1)
        engine.setEnvironmentActive(true)
        engine.advance(by: 0.5)
        XCTAssertEqual(engine.snapshot.revealedCount, 0)

        engine.setMotionAllowed(false)
        XCTAssertEqual(engine.snapshot.revealedCount, 5)
        XCTAssertFalse(engine.shouldAdvance)

        engine.setMotionAllowed(true)
        XCTAssertEqual(engine.snapshot.revealedCount, 5)
        XCTAssertFalse(engine.shouldAdvance)
    }

    func testContentAssignedDuringReduceMotionIsImmediatelyComplete() {
        let engine = makeEngine(unitCount: 2, speed: 2, delay: 0)
        engine.setMotionAllowed(false)
        XCTAssertEqual(engine.snapshot.revealedCount, 2)

        engine.updateUnitCount(6)
        XCTAssertEqual(engine.snapshot.revealedCount, 6)
    }

    func testEmptyAndSingleUnitInputsDoNotScheduleAfterPresentation() {
        let empty = makeEngine(unitCount: 0, speed: 20, delay: 0)
        empty.setEnvironmentActive(true)
        XCTAssertEqual(empty.snapshot.revealedCount, 0)
        XCTAssertTrue(empty.snapshot.isComplete)
        XCTAssertFalse(empty.shouldAdvance)

        let single = makeEngine(unitCount: 1, speed: 20, delay: 0.5)
        single.setEnvironmentActive(true)
        XCTAssertTrue(single.shouldAdvance)
        single.advance(by: 0.5)
        XCTAssertEqual(single.snapshot.revealedCount, 1)
        XCTAssertFalse(single.shouldAdvance)
    }

    func testSnapshotCallbackRunsOnlyForRenderableChanges() {
        let engine = makeEngine(unitCount: 3, speed: 2, delay: 1)
        var snapshots: [_ITextTypewriterSnapshot] = []
        engine.onSnapshotChanged = { snapshots.append($0) }
        engine.setEnvironmentActive(true)
        engine.advance(by: 0.5)
        XCTAssertTrue(snapshots.isEmpty)

        engine.advance(by: 0.5)
        XCTAssertEqual(snapshots.map(\.revealedCount), [1])
    }

    private func makeEngine(
        unitCount: Int,
        speed: Double,
        delay: TimeInterval
    ) -> _ITextTypewriterEngine {
        _ITextTypewriterEngine(
            unitCount: unitCount,
            configuration: .init(
                charactersPerSecond: speed,
                initialDelay: delay
            )
        )
    }
}
