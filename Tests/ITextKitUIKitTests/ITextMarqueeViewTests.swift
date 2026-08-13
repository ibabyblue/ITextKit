import UIKit
import XCTest
@testable import ITextKit

@MainActor
final class ITextMarqueeViewTests: XCTestCase {
    func testOverflowingTravelUsesOneLinearRepeatingLayerAnimation() throws {
        let (marquee, window) = makeHostedMarquee(styled: false)
        defer { window.isHidden = true }
        let animation = try XCTUnwrap(marquee._travelAnimation)
        let labels = marquee._movingLabels
        let cycleDistance = labels[1].frame.minX - labels[0].frame.minX
        let fromValue = try XCTUnwrap(animation.fromValue as? NSNumber)
        let toValue = try XCTUnwrap(animation.toValue as? NSNumber)

        XCTAssertEqual(animation.keyPath, "transform.translation.x")
        assertLinear(animation.timingFunction)
        XCTAssertEqual(animation.repeatCount, Float.infinity)
        XCTAssertEqual(
            animation.duration,
            cycleDistance / marquee.configuration.speed,
            accuracy: 0.001
        )
        XCTAssertEqual(fromValue.doubleValue, 0)
        XCTAssertEqual(
            toValue.doubleValue,
            -Double(cycleDistance),
            accuracy: 0.001
        )
    }

    func testInheritedRTLTravelsInPositivePhysicalDirection() throws {
        let (marquee, window) = makeHostedMarquee(
            styled: false,
            direction: .forceRightToLeft
        )
        defer { window.isHidden = true }
        let animation = try XCTUnwrap(marquee._travelAnimation)

        XCTAssertGreaterThan((animation.toValue as? NSNumber)?.doubleValue ?? 0, 0)
    }

    func testPauseResumeAndEnvironmentFreezeLayerTime() {
        let (marquee, window) = makeHostedMarquee(styled: false)
        defer { window.isHidden = true }
        let engine = marqueeEngine(marquee)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        marquee.pause()
        let callerPausedTime = marquee._motionLayerTimeOffset
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(marquee._motionLayerTimeOffset, callerPausedTime)
        XCTAssertEqual(marquee._motionLayerSpeed, 0)

        marquee.resume()
        XCTAssertEqual(marquee._motionLayerSpeed, 1)
        engine?.setEnvironmentActive(false)
        let environmentPausedTime = marquee._motionLayerTimeOffset
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(marquee.playbackState, .playing)
        XCTAssertEqual(marquee._motionLayerSpeed, 0)
        XCTAssertEqual(marquee._motionLayerTimeOffset, environmentPausedTime)

        engine?.setEnvironmentActive(true)
        XCTAssertEqual(marquee.playbackState, .playing)
        XCTAssertEqual(marquee._motionLayerSpeed, 1)

        marquee.pause()
        engine?.setEnvironmentActive(false)
        engine?.setEnvironmentActive(true)
        XCTAssertEqual(marquee.playbackState, .paused)
        XCTAssertEqual(marquee._motionLayerSpeed, 0)
    }

    func testDetachmentRemovesAnimationAndReattachmentReconstructsTravel() {
        let (marquee, window) = makeHostedMarquee(styled: false)
        defer { window.isHidden = true }
        let controller = window.rootViewController
        let engine = marqueeEngine(marquee)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertTrue(marquee._hasActiveTravelAnimation)

        marquee.removeFromSuperview()
        XCTAssertFalse(marquee._hasActiveTravelAnimation)
        XCTAssertEqual(marquee.playbackState, .playing)

        controller?.view.addSubview(marquee)
        engine?.setEnvironmentActive(true)
        marquee.layoutIfNeeded()
        XCTAssertTrue(marquee._hasActiveTravelAnimation)
        let reconstructed = marquee._travelAnimation?.fromValue as? NSNumber
        XCTAssertLessThan(reconstructed?.doubleValue ?? 0, 0)
        XCTAssertTrue(marquee.isAccessibilityElement)
        XCTAssertTrue(marquee._movingLabels.allSatisfy { !$0.isAccessibilityElement })
    }

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
        let presentationTranslation = marquee._motionPresentationTranslationX

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
        XCTAssertNotEqual(marquee._motionPresentationTranslationX, presentationTranslation)
        XCTAssertNil(Mirror(reflecting: marquee).descendant("displayLink"))
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
        XCTAssertFalse(marquee._hasActiveTravelAnimation)
    }

    func testZeroSpeedStoppedAndMotionDisallowedInstallNoTravelAnimation() {
        let (zeroSpeed, zeroSpeedWindow) = makeHostedMarquee(
            styled: false,
            speed: 0
        )
        defer { zeroSpeedWindow.isHidden = true }
        XCTAssertFalse(zeroSpeed._hasActiveTravelAnimation)

        let (stopped, stoppedWindow) = makeHostedMarquee(styled: false)
        defer { stoppedWindow.isHidden = true }
        stopped.stop()
        stopped.layoutIfNeeded()
        XCTAssertFalse(stopped._hasActiveTravelAnimation)

        let (motionDisallowed, motionDisallowedWindow) = makeHostedMarquee(styled: false)
        defer { motionDisallowedWindow.isHidden = true }
        marqueeEngine(motionDisallowed)?.setMotionAllowed(false)
        motionDisallowed.layoutIfNeeded()
        XCTAssertFalse(motionDisallowed._hasActiveTravelAnimation)
    }

    private func makeHostedMarquee(
        styled: Bool,
        text: String = "A long marquee fixture that must overflow its narrow viewport",
        direction: UISemanticContentAttribute = .unspecified,
        speed: CGFloat = 40
    ) -> (ITextMarqueeView, UIWindow) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        let controller = UIViewController()
        window.rootViewController = controller
        let marquee = ITextMarqueeView(
            text: text,
            configuration: .init(speed: speed, spacing: 24, initialDelay: 0),
            playbackState: .playing
        )
        marquee.semanticContentAttribute = direction
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
        marqueeEngine(marquee)?.setEnvironmentActive(true)
        marquee.layoutIfNeeded()
        return (marquee, window)
    }

    private func marqueeEngine(
        _ marquee: ITextMarqueeView
    ) -> _ITextMarqueeEngine? {
        Mirror(reflecting: marquee).descendant("engine") as? _ITextMarqueeEngine
    }

    private func assertLinear(
        _ timingFunction: CAMediaTimingFunction?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let timingFunction else {
            XCTFail("Missing timing function", file: file, line: line)
            return
        }
        var first = [Float](repeating: 0, count: 2)
        var second = [Float](repeating: 0, count: 2)
        timingFunction.getControlPoint(at: 1, values: &first)
        timingFunction.getControlPoint(at: 2, values: &second)
        XCTAssertEqual(first, [0, 0], file: file, line: line)
        XCTAssertEqual(second, [1, 1], file: file, line: line)
    }
}
