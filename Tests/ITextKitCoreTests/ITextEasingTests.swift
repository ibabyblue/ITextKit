import XCTest
@testable import ITextKit

final class ITextEasingTests: XCTestCase {
    func testEaseInOutHasExpectedEndpointsMidpointAndSymmetry() {
        XCTAssertEqual(_ITextEasing.easeInOut(-1), 0)
        XCTAssertEqual(_ITextEasing.easeInOut(0), 0)
        XCTAssertEqual(_ITextEasing.easeInOut(0.5), 0.5, accuracy: 0.000_1)
        XCTAssertEqual(_ITextEasing.easeInOut(1), 1)
        XCTAssertEqual(_ITextEasing.easeInOut(2), 1)

        let firstQuarter = _ITextEasing.easeInOut(0.25)
        let thirdQuarter = _ITextEasing.easeInOut(0.75)
        XCTAssertLessThan(firstQuarter, 0.25)
        XCTAssertEqual(firstQuarter, 1 - thirdQuarter, accuracy: 0.000_1)
    }

    func testRotatorMovementAndFadingStartAndFinishTogetherWithVisibleCrossFade() {
        for linearProgress in stride(from: 0.0, through: 1.0, by: 0.05) {
            let presentation = _ITextRotatorTransitionPresentation(
                linearProgress: linearProgress,
                reduceMotion: false
            )

            if linearProgress > 0, linearProgress < 1 {
                XCTAssertLessThan(presentation.outgoing.opacity, 1)
                XCTAssertGreaterThan(presentation.outgoing.opacity, 0)
                XCTAssertGreaterThan(presentation.incoming.opacity, 0)
                XCTAssertLessThan(presentation.incoming.opacity, 1)
            }
        }

        let midpoint = _ITextRotatorTransitionPresentation(
            linearProgress: 0.5,
            reduceMotion: false
        )
        XCTAssertEqual(midpoint.outgoing.opacity, 0.25, accuracy: 0.000_1)
        XCTAssertEqual(midpoint.incoming.opacity, 0.25, accuracy: 0.000_1)
        XCTAssertEqual(
            midpoint.outgoing.opacity + midpoint.incoming.opacity,
            0.5,
            accuracy: 0.000_1
        )
    }
}
