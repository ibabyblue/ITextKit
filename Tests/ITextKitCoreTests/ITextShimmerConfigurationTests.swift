import CoreGraphics
import XCTest
@testable import ITextKit

final class ITextShimmerConfigurationTests: XCTestCase {
    func testDefaultsMatchConfirmedWorkingStyle() {
        let value = ITextShimmerConfiguration.default

        XCTAssertEqual(value.duration, 1.5)
        XCTAssertEqual(value.bandWidth, 0.28)
        XCTAssertEqual(value.intensity, 0.85)
        XCTAssertEqual(value.direction, .leadingToTrailing)
    }

    func testPublicValuesRemainUnchangedUntilConsumption() {
        let value = ITextShimmerConfiguration(
            duration: -1,
            bandWidth: 2,
            intensity: -3,
            direction: .trailingToLeading
        )

        XCTAssertEqual(value.duration, -1)
        XCTAssertEqual(value.bandWidth, 2)
        XCTAssertEqual(value.intensity, -3)
        XCTAssertEqual(value.direction, .trailingToLeading)
    }

    func testResolvedConfigurationClampsFiniteValues() {
        let value = ITextShimmerConfiguration(
            duration: 0.01,
            bandWidth: 2,
            intensity: -1,
            direction: .trailingToLeading
        ).resolved

        XCTAssertEqual(value.duration, 0.2)
        XCTAssertEqual(value.bandWidth, 1)
        XCTAssertEqual(value.intensity, 0)
        XCTAssertEqual(value.direction, .trailingToLeading)
    }

    func testResolvedConfigurationFallsBackForNonFiniteValues() {
        let value = ITextShimmerConfiguration(
            duration: .nan,
            bandWidth: .infinity,
            intensity: -.infinity
        ).resolved

        XCTAssertEqual(value.duration, 1.5)
        XCTAssertEqual(value.bandWidth, 0.28)
        XCTAssertEqual(value.intensity, 0.85)
    }
}
