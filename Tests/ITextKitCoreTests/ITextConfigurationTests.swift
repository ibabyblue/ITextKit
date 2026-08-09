import CoreGraphics
import XCTest
@testable import ITextKit

final class ITextConfigurationTests: XCTestCase {
    func testRotatorDefaults() {
        XCTAssertEqual(ITextRotatorConfiguration.default.interval, 3)
        XCTAssertEqual(ITextRotatorConfiguration.default.transitionDuration, 0.35)
    }

    func testRotatorInvalidValuesAreNormalizedAtConsumption() {
        let negative = ITextRotatorConfiguration(interval: -2, transitionDuration: -1).resolved
        XCTAssertEqual(negative.interval, 0)
        XCTAssertEqual(negative.transitionDuration, 0)

        let nonfinite = ITextRotatorConfiguration(
            interval: .infinity,
            transitionDuration: .nan
        ).resolved
        XCTAssertEqual(nonfinite.interval, 3)
        XCTAssertEqual(nonfinite.transitionDuration, 0.35)
    }

    func testMarqueeDefaults() {
        XCTAssertEqual(ITextMarqueeConfiguration.default.speed, 30)
        XCTAssertEqual(ITextMarqueeConfiguration.default.spacing, 24)
        XCTAssertEqual(ITextMarqueeConfiguration.default.initialDelay, 1)
    }

    func testMarqueeInvalidValuesAreNormalizedAtConsumption() {
        let negative = ITextMarqueeConfiguration(
            speed: -20,
            spacing: -8,
            initialDelay: -3
        ).resolved
        XCTAssertEqual(negative.speed, 0)
        XCTAssertEqual(negative.spacing, 0)
        XCTAssertEqual(negative.initialDelay, 0)

        let nonfinite = ITextMarqueeConfiguration(
            speed: .infinity,
            spacing: .nan,
            initialDelay: .infinity
        ).resolved
        XCTAssertEqual(nonfinite.speed, 30)
        XCTAssertEqual(nonfinite.spacing, 24)
        XCTAssertEqual(nonfinite.initialDelay, 1)
    }
}
