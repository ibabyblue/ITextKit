import UIKit
import XCTest
@testable import ITextKit

@MainActor
final class ITextMarqueeViewTests: XCTestCase {
    func testSteadyMotionKeepsStyledCopyGeometryAndRenderingStable() throws {
        let (marquee, window) = makeHostedMarquee(styled: true)
        defer { window.isHidden = true }
        let engine = try XCTUnwrap(
            Mirror(reflecting: marquee).descendant("engine")
                as? _ITextMarqueeEngine
        )
        engine.setEnvironmentActive(true)
        marquee.layoutIfNeeded()
        marquee._movingLabels.forEach { $0.layer.displayIfNeeded() }
        // Allow the first window-backed render pass to finish before recording steady-state
        // generations. This excludes the copies' required initial draw from travel invalidation.
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        marquee._movingLabels.forEach { $0.layer.displayIfNeeded() }

        let measurement = marquee._measurementGeneration
        let frames = marquee._movingLabels.map(\.frame)
        let layoutGenerations = marquee._movingLabels.map(\._layoutGeneration)
        let drawingGenerations = marquee._movingLabels.map(\._drawingGeneration)

        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        marquee.layoutIfNeeded()
        marquee._movingLabels.forEach { $0.layer.displayIfNeeded() }

        XCTAssertEqual(marquee._measurementGeneration, measurement)
        XCTAssertEqual(marquee._movingLabels.map(\.frame), frames)
        XCTAssertEqual(
            marquee._movingLabels.map(\._layoutGeneration),
            layoutGenerations
        )
        XCTAssertEqual(
            marquee._movingLabels.map(\._drawingGeneration),
            drawingGenerations
        )
    }

    func testMovingCopiesHaveExactSpacingAndSingleAccessibilityOwner() {
        let (marquee, window) = makeHostedMarquee(styled: false)
        defer { window.isHidden = true }
        let labels = marquee._movingLabels

        XCTAssertEqual(labels.count, 2)
        XCTAssertEqual(labels[0].frame.width, labels[1].frame.width)
        XCTAssertEqual(
            labels[1].frame.minX - labels[0].frame.maxX,
            marquee.configuration.spacing,
            accuracy: 0.001
        )
        XCTAssertTrue(marquee.isAccessibilityElement)
        XCTAssertEqual(marquee.accessibilityLabel, marquee.text)
        XCTAssertTrue(labels.allSatisfy { !$0.isAccessibilityElement })
    }

    func testRestartAfterStoppedPresentationRestoresMovingCopyGeometry() {
        let (marquee, window) = makeHostedMarquee(styled: false)
        defer { window.isHidden = true }

        marquee.stop()
        marquee.layoutIfNeeded()
        XCTAssertEqual(marquee._movingLabels[0].frame.width, marquee.bounds.width)
        XCTAssertTrue(marquee._movingLabels[1].isHidden)

        marquee.start()
        marquee.layoutIfNeeded()
        let labels = marquee._movingLabels
        XCTAssertGreaterThan(labels[0].frame.width, marquee.bounds.width)
        XCTAssertEqual(
            labels[1].frame.minX - labels[0].frame.maxX,
            marquee.configuration.spacing,
            accuracy: 0.001
        )
        XCTAssertFalse(labels[1].isHidden)
    }

    func testFittingContentUsesOneStaticTruncatedLabel() {
        let (marquee, window) = makeHostedMarquee(
            styled: false,
            text: "Short"
        )
        defer { window.isHidden = true }

        XCTAssertEqual(marquee._movingLabels[0].frame, marquee.bounds)
        XCTAssertEqual(marquee._movingLabels[0].lineBreakMode, .byTruncatingTail)
        XCTAssertTrue(marquee._movingLabels[1].isHidden)
    }

    private func makeHostedMarquee(
        styled: Bool,
        text: String = "A long marquee fixture that must overflow its narrow viewport"
    ) -> (ITextMarqueeView, UIWindow) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        let controller = UIViewController()
        window.rootViewController = controller
        let marquee = ITextMarqueeView(
            text: text,
            configuration: .init(speed: 40, spacing: 24, initialDelay: 0),
            playbackState: .playing
        )
        marquee.frame = CGRect(x: 20, y: 20, width: 180, height: 40)
        if styled {
            marquee.font = .systemFont(ofSize: 20, weight: .bold)
            marquee.textStyle = .init(
                fill: .linearGradient(.init(
                    colors: [.systemPink, .systemOrange]
                )),
                stroke: .init(
                    paint: .linearGradient(.init(colors: [.white, .black])),
                    width: 1
                )
            )
        }
        controller.view.addSubview(marquee)
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        marquee.layoutIfNeeded()
        return (marquee, window)
    }
}
