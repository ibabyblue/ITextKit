import UIKit
import XCTest
@testable import ITextKit

@MainActor
final class ITextKitUIKitAPITests: XCTestCase {
    func testRotatorMovesOutgoingTextUpAndIncomingTextFromBelowWhileCrossFading() throws {
        let view = ITextRotatorView(
            texts: ["First", "Second"],
            configuration: ITextRotatorConfiguration(
                interval: 1,
                transitionDuration: 1
            ),
            playbackState: .paused
        )
        view.frame = CGRect(x: 0, y: 0, width: 160, height: 40)

        let engine = try XCTUnwrap(
            Mirror(reflecting: view).descendant("engine") as? _ITextRotatorEngine
        )
        engine.setEnvironmentActive(true)
        engine.setPlaybackState(.playing)
        let labels = view.subviews.compactMap { $0 as? UILabel }
        XCTAssertEqual(labels.count, 2)
        engine.advance(by: 1)

        for step in 1...3 {
            engine.advance(by: 0.25)
            view.layoutIfNeeded()
            let presentation = _ITextRotatorTransitionPresentation(
                linearProgress: Double(step) * 0.25,
                reduceMotion: UIAccessibility.isReduceMotionEnabled
            )

            XCTAssertEqual(labels[0].text, "First")
            XCTAssertEqual(labels[1].text, "Second")
            XCTAssertEqual(
                labels[0].alpha,
                presentation.outgoing.opacity,
                accuracy: 0.01
            )
            XCTAssertEqual(
                labels[1].alpha,
                presentation.incoming.opacity,
                accuracy: 0.01
            )

            if !UIAccessibility.isReduceMotionEnabled {
                XCTAssertEqual(
                    -labels[0].frame.minY / labels[0].bounds.height,
                    -presentation.outgoing.verticalOffsetFactor,
                    accuracy: 0.02
                )
                XCTAssertEqual(
                    labels[1].frame.minY / labels[1].bounds.height,
                    presentation.incoming.verticalOffsetFactor,
                    accuracy: 0.02
                )
            }
        }

        engine.setPlaybackState(.paused)
    }

    func testRotatorPublicStylePlaybackAndAccessibility() {
        let view = ITextRotatorView(
            texts: ["First", "A much longer second line that wraps"],
            playbackState: .paused
        )
        view.font = .preferredFont(forTextStyle: .headline)
        view.textColor = .systemPurple
        view.textAlignment = .center
        view.numberOfLines = 0
        view.frame = CGRect(x: 0, y: 0, width: 120, height: 80)
        view.layoutIfNeeded()

        XCTAssertEqual(view.playbackState, .paused)
        XCTAssertEqual(view.accessibilityLabel, "First")
        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertEqual(view.subviews.count, 2)
        XCTAssertTrue(view.subviews.allSatisfy { !$0.isAccessibilityElement })
        XCTAssertGreaterThan(view.intrinsicContentSize.height, 0)
        view.resume()
        XCTAssertEqual(view.playbackState, .playing)
        view.pause()
        view.start()
        XCTAssertEqual(view.playbackState, .playing)
        view.stop()
        XCTAssertEqual(view.playbackState, .stopped)
    }

    func testRotatorAttributedContentUsesNativeLayoutAndPlainAccessibility() {
        let large = NSAttributedString(
            string: "Large rich text",
            attributes: [
                .font: UIFont.systemFont(ofSize: 34, weight: .bold),
                .foregroundColor: UIColor.systemPurple,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        let view = ITextRotatorView(
            attributedTexts: [large, NSAttributedString(string: "Next")],
            playbackState: .paused
        )
        let plain = ITextRotatorView(texts: ["Large rich text"], playbackState: .paused)
        view.font = .preferredFont(forTextStyle: .caption1)
        view.textColor = .label
        view.textAlignment = .center
        view.adjustsFontForContentSizeCategory = true

        XCTAssertEqual(view.texts, ["Large rich text", "Next"])
        XCTAssertTrue(view.attributedTexts[0].isEqual(to: large))
        XCTAssertEqual(view.accessibilityLabel, "Large rich text")
        XCTAssertGreaterThan(view.intrinsicContentSize.height, plain.intrinsicContentSize.height)
        let labels = view.subviews.compactMap { $0 as? UILabel }
        XCTAssertTrue(labels[0].attributedText?.isEqual(to: large) == true)
    }

    func testRotatorStyleOnlyChangeResetsFirstItemAndPreservesPause() throws {
        let values = [
            NSAttributedString(string: "First", attributes: [.foregroundColor: UIColor.red]),
            NSAttributedString(string: "Second", attributes: [.foregroundColor: UIColor.red])
        ]
        let view = ITextRotatorView(
            attributedTexts: values,
            configuration: .init(interval: 1, transitionDuration: 0),
            playbackState: .playing
        )
        let engine = try XCTUnwrap(
            Mirror(reflecting: view).descendant("engine") as? _ITextRotatorEngine
        )
        engine.setEnvironmentActive(true)
        engine.advance(by: 1)
        XCTAssertEqual(engine.snapshot.currentIndex, 1)

        view.pause()
        view.attributedTexts = values.map {
            NSAttributedString(string: $0.string, attributes: [.foregroundColor: UIColor.blue])
        }

        XCTAssertEqual(engine.snapshot.currentIndex, 0)
        XCTAssertEqual(view.playbackState, .paused)
        XCTAssertEqual(view.accessibilityLabel, "First")
    }

    func testRotatorTakesImmutableSnapshotsAndPlainSetterDropsAttributes() {
        let mutable = NSMutableAttributedString(
            string: "Snapshot",
            attributes: [.foregroundColor: UIColor.red]
        )
        let view = ITextRotatorView(attributedTexts: [mutable], playbackState: .paused)
        mutable.addAttribute(.foregroundColor, value: UIColor.blue, range: NSRange(location: 0, length: mutable.length))

        XCTAssertEqual(
            view.attributedTexts[0].attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor,
            .red
        )

        view.texts = ["Plain"]
        XCTAssertEqual(view.attributedTexts[0].string, "Plain")
        XCTAssertNil(view.attributedTexts[0].attribute(.foregroundColor, at: 0, effectiveRange: nil))
    }

    func testMarqueePublicStylePlaybackAndAccessibility() {
        let view = ITextMarqueeView(
            text: "A long marquee line that should overflow this narrow viewport",
            playbackState: .paused
        )
        view.font = .preferredFont(forTextStyle: .body)
        view.textColor = .systemBlue
        view.textAlignment = .natural
        view.frame = CGRect(x: 0, y: 0, width: 80, height: 30)
        view.layoutIfNeeded()

        XCTAssertEqual(view.playbackState, .paused)
        XCTAssertEqual(view.accessibilityLabel, view.text)
        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertEqual(view.subviews.count, 2)
        XCTAssertTrue(view.subviews.allSatisfy { !$0.isAccessibilityElement })
        XCTAssertGreaterThan(view.intrinsicContentSize.height, 0)
        let labels = view.subviews.compactMap { $0 as? UILabel }
        XCTAssertEqual(labels.map(\.text), [view.text, view.text])
        XCTAssertTrue(labels.contains { label in
            !label.isHidden && label.frame.intersects(view.bounds)
        })

        view.resume()
        XCTAssertEqual(view.playbackState, .playing)
        view.pause()
        view.start()
        XCTAssertEqual(view.playbackState, .playing)
        view.stop()
        XCTAssertEqual(view.playbackState, .stopped)
    }

    func testMarqueeAttributedContentUsesNativeWidthAndImmutableSnapshot() {
        let mutable = NSMutableAttributedString(
            string: "Wide rich marquee",
            attributes: [
                .font: UIFont.systemFont(ofSize: 32, weight: .bold),
                .kern: 3,
                .foregroundColor: UIColor.systemBlue
            ]
        )
        let view = ITextMarqueeView(attributedText: mutable, playbackState: .paused)
        let plain = ITextMarqueeView(text: mutable.string, playbackState: .paused)
        let originalWidth = view.intrinsicContentSize.width
        view.font = .preferredFont(forTextStyle: .caption1)
        view.textColor = .label
        view.adjustsFontForContentSizeCategory = true
        mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: 8), range: NSRange(location: 0, length: mutable.length))

        XCTAssertGreaterThan(originalWidth, plain.intrinsicContentSize.width)
        XCTAssertEqual(view.intrinsicContentSize.width, originalWidth, accuracy: 0.01)
        XCTAssertEqual(view.accessibilityLabel, "Wide rich marquee")
        let labels = view.subviews.compactMap { $0 as? UILabel }
        XCTAssertTrue(labels.allSatisfy { label in
            label.attributedText.map(view.attributedText.isEqual(to:)) == true
        })
    }

    func testMarqueeStyleOnlyChangeRestartsAndPreservesPause() throws {
        let view = ITextMarqueeView(
            attributedText: NSAttributedString(
                string: "A long rich marquee that overflows",
                attributes: [.foregroundColor: UIColor.red]
            ),
            configuration: .init(speed: 100, spacing: 20, initialDelay: 0),
            playbackState: .playing
        )
        view.frame = CGRect(x: 0, y: 0, width: 40, height: 30)
        view.layoutIfNeeded()
        let engine = try XCTUnwrap(
            Mirror(reflecting: view).descendant("engine") as? _ITextMarqueeEngine
        )
        engine.setEnvironmentActive(true)
        engine.advance(by: 0.2)
        XCTAssertGreaterThan(engine.snapshot.offset, 0)

        view.pause()
        view.attributedText = NSAttributedString(
            string: view.text,
            attributes: [.foregroundColor: UIColor.blue]
        )

        XCTAssertEqual(engine.snapshot.offset, 0)
        XCTAssertEqual(view.playbackState, .paused)
        XCTAssertEqual(view.accessibilityLabel, view.text)
    }
}
