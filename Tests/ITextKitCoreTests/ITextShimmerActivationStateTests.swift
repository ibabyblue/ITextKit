import CoreGraphics
import XCTest
@testable import ITextKit

final class ITextShimmerActivationStateTests: XCTestCase {
    func testAnimationRunsOnlyWhenEveryConditionAllowsIt() {
        XCTAssertTrue(ITextShimmerActivationState.shouldAnimate(
            isRequested: true,
            hasContent: true,
            hasBounds: true,
            isInWindow: true,
            reduceMotion: false,
            intensity: 0.85
        ))

        let blockedCases: [(Bool, Bool, Bool, Bool, Bool, CGFloat)] = [
            (false, true, true, true, false, 0.85),
            (true, false, true, true, false, 0.85),
            (true, true, false, true, false, 0.85),
            (true, true, true, false, false, 0.85),
            (true, true, true, true, true, 0.85),
            (true, true, true, true, false, 0)
        ]

        for value in blockedCases {
            XCTAssertFalse(ITextShimmerActivationState.shouldAnimate(
                isRequested: value.0,
                hasContent: value.1,
                hasBounds: value.2,
                isInWindow: value.3,
                reduceMotion: value.4,
                intensity: value.5
            ))
        }
    }
}
