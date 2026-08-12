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

    func testRotatorResizesWhenInheritedContentSizeCategoryChanges() {
        let view = ITextRotatorView(texts: ["Dynamic type"], playbackState: .paused)
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true

        assertViewResizesForInheritedContentSizeCategory(view)
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

    func testMarqueeInheritsRightToLeftLayoutDirectionFromSuperview() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 80))
        let host = UIViewController()
        let child = UIViewController()
        host.addChild(child)
        host.view.addSubview(child.view)
        child.view.frame = host.view.bounds
        child.didMove(toParent: host)
        host.setOverrideTraitCollection(
            UITraitCollection(layoutDirection: .rightToLeft),
            forChild: child
        )
        window.rootViewController = host

        let view = ITextMarqueeView(
            text: "A long marquee line that overflows its viewport",
            configuration: .init(speed: 30, spacing: 24, initialDelay: 0),
            playbackState: .paused
        )
        view.frame = CGRect(x: 0, y: 0, width: 80, height: 30)
        child.view.addSubview(view)
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        child.view.layoutIfNeeded()
        view.layoutIfNeeded()

        XCTAssertEqual(view.effectiveUserInterfaceLayoutDirection, .rightToLeft)
        let labels = try XCTUnwrap(view.subviews as? [UILabel])
        XCTAssertEqual(labels.count, 2)
        XCTAssertLessThan(labels[1].frame.minX, labels[0].frame.minX)
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

    func testMarqueeResizesWhenInheritedContentSizeCategoryChanges() {
        let view = ITextMarqueeView(text: "Dynamic type", playbackState: .paused)
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true

        assertViewResizesForInheritedContentSizeCategory(view)
    }

    func testTypewriterPlainAPIStartsWhenEnvironmentBecomesActive() throws {
        let view = ITextTypewriterView(
            text: "ABC",
            configuration: .init(charactersPerSecond: 2, initialDelay: 0)
        )
        let label = try XCTUnwrap(view.subviews.first as? UILabel)
        let engine = try XCTUnwrap(
            Mirror(reflecting: view).descendant("engine") as? _ITextTypewriterEngine
        )

        XCTAssertEqual(label.text, "")
        XCTAssertEqual(view.accessibilityLabel, "ABC")
        XCTAssertEqual(view.intrinsicContentSize, .zero)
        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertFalse(view.isUserInteractionEnabled)
        XCTAssertFalse(label.isAccessibilityElement)

        engine.setEnvironmentActive(true)
        XCTAssertEqual(label.text, "A")
        let firstSize = view.intrinsicContentSize
        XCTAssertGreaterThan(firstSize.width, 0)
        XCTAssertGreaterThan(firstSize.height, 0)

        engine.advance(by: 0.5)
        XCTAssertEqual(label.text, "AB")
        XCTAssertGreaterThan(view.intrinsicContentSize.width, firstSize.width)
    }

    func testTypewriterUsesComposedCharactersAndPreservesRichAttributes() throws {
        let family = "👨‍👩‍👧‍👦"
        let mutable = NSMutableAttributedString(
            string: family + "A",
            attributes: [.foregroundColor: UIColor.systemPurple]
        )
        mutable.addAttribute(
            .underlineStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: NSRange(location: 0, length: (family as NSString).length)
        )
        let view = ITextTypewriterView(attributedText: mutable)
        let label = try XCTUnwrap(view.subviews.first as? UILabel)
        let engine = try XCTUnwrap(
            Mirror(reflecting: view).descendant("engine") as? _ITextTypewriterEngine
        )

        XCTAssertEqual(engine.snapshot.unitCount, 2)
        engine.setEnvironmentActive(true)
        XCTAssertEqual(label.text, family)
        XCTAssertEqual(
            label.attributedText?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor,
            .systemPurple
        )
        XCTAssertEqual(
            label.attributedText?.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int,
            NSUnderlineStyle.single.rawValue
        )

        engine.advance(by: 0.05)
        XCTAssertEqual(label.text, family + "A")
    }

    func testTypewriterTakesImmutableSnapshotAndIgnoresEqualAssignment() throws {
        let mutable = NSMutableAttributedString(
            string: "AB",
            attributes: [.foregroundColor: UIColor.red]
        )
        let view = ITextTypewriterView(attributedText: mutable)
        let engine = try XCTUnwrap(
            Mirror(reflecting: view).descendant("engine") as? _ITextTypewriterEngine
        )
        engine.setEnvironmentActive(true)
        engine.advance(by: 0.05)
        XCTAssertEqual(engine.snapshot.revealedCount, 2)

        mutable.addAttribute(
            .foregroundColor,
            value: UIColor.blue,
            range: NSRange(location: 0, length: mutable.length)
        )
        XCTAssertEqual(
            view.attributedText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor,
            .red
        )

        view.attributedText = view.attributedText
        XCTAssertEqual(engine.snapshot.revealedCount, 2)
    }

    func testTypewriterPlainSetterDropsRichAttributesAndRestarts() throws {
        let view = ITextTypewriterView(
            attributedText: NSAttributedString(
                string: "AB",
                attributes: [.foregroundColor: UIColor.red]
            )
        )
        let label = try XCTUnwrap(view.subviews.first as? UILabel)
        let engine = try XCTUnwrap(
            Mirror(reflecting: view).descendant("engine") as? _ITextTypewriterEngine
        )
        engine.setEnvironmentActive(true)
        engine.advance(by: 0.05)
        XCTAssertEqual(engine.snapshot.revealedCount, 2)

        view.text = "Plain"

        XCTAssertEqual(engine.snapshot.revealedCount, 1)
        XCTAssertEqual(label.text, "P")
        XCTAssertNil(
            view.attributedText.attribute(.foregroundColor, at: 0, effectiveRange: nil)
        )
    }

    func testTypewriterStyleOnlyContentAndConfigurationChangesRestart() throws {
        let view = ITextTypewriterView(
            attributedText: NSAttributedString(
                string: "ABC",
                attributes: [.foregroundColor: UIColor.red]
            )
        )
        let engine = try XCTUnwrap(
            Mirror(reflecting: view).descendant("engine") as? _ITextTypewriterEngine
        )
        engine.setEnvironmentActive(true)
        engine.advance(by: 0.1)
        XCTAssertEqual(engine.snapshot.revealedCount, 3)

        view.attributedText = NSAttributedString(
            string: "ABC",
            attributes: [.foregroundColor: UIColor.blue]
        )
        XCTAssertEqual(engine.snapshot.revealedCount, 1)

        view.configuration = .init(charactersPerSecond: 10, initialDelay: 1)
        XCTAssertEqual(engine.snapshot.revealedCount, 0)
    }

    func testTypewriterViewLevelStyleChangesPreserveProgressAndInlineAttributes() throws {
        let rich = NSAttributedString(
            string: "ABC",
            attributes: [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.systemGreen
            ]
        )
        let view = ITextTypewriterView(attributedText: rich)
        let label = try XCTUnwrap(view.subviews.first as? UILabel)
        let engine = try XCTUnwrap(
            Mirror(reflecting: view).descendant("engine") as? _ITextTypewriterEngine
        )
        engine.setEnvironmentActive(true)
        engine.advance(by: 0.05)
        XCTAssertEqual(engine.snapshot.revealedCount, 2)

        view.font = .preferredFont(forTextStyle: .caption1)
        view.textColor = .label
        view.textAlignment = .center
        view.numberOfLines = 0
        view.lineBreakMode = .byWordWrapping
        view.adjustsFontForContentSizeCategory = true

        XCTAssertEqual(engine.snapshot.revealedCount, 2)
        XCTAssertEqual(label.text, "AB")
        XCTAssertEqual(
            label.attributedText?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor,
            .systemGreen
        )
    }

    func testTypewriterSizeThatFitsWrapsAtCallerWidthAndGrowsHeight() throws {
        let view = ITextTypewriterView(
            text: "A typewriter prefix grows and wraps using native word boundaries."
        )
        let engine = try XCTUnwrap(
            Mirror(reflecting: view).descendant("engine") as? _ITextTypewriterEngine
        )
        engine.setEnvironmentActive(true)
        engine.advance(by: 10)

        let natural = view.sizeThatFits(CGSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        ))
        let constrained = view.sizeThatFits(CGSize(
            width: 90,
            height: CGFloat.greatestFiniteMagnitude
        ))
        XCTAssertLessThan(constrained.width, natural.width)
        XCTAssertGreaterThan(constrained.height, natural.height)
    }

    private func assertViewResizesForInheritedContentSizeCategory(
        _ view: UIView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        let host = UIViewController()
        let child = UIViewController()
        host.addChild(child)
        host.view.addSubview(child.view)
        child.view.frame = host.view.bounds
        child.didMove(toParent: host)
        window.rootViewController = host

        view.translatesAutoresizingMaskIntoConstraints = false
        child.view.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: child.view.leadingAnchor),
            view.topAnchor.constraint(equalTo: child.view.topAnchor),
            view.widthAnchor.constraint(equalToConstant: 200)
        ])

        host.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .extraSmall),
            forChild: child
        )
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        child.view.layoutIfNeeded()
        let smallHeight = view.bounds.height

        host.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            forChild: child
        )
        host.view.layoutIfNeeded()
        child.view.layoutIfNeeded()

        XCTAssertGreaterThan(view.bounds.height, smallHeight, file: file, line: line)
        window.isHidden = true
    }

}
