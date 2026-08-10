# ITextKit Shimmer Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the complete standalone IShimmerText highlight-sweep behavior into the ITextKit module under the confirmed `ITextShimmer*` interface.

**Architecture:** Add a deep shimmer module whose public seam is one configuration, one semantic direction, one SwiftUI modifier, and one UILabel subclass. Share only deterministic configuration, activation, direction, and geometry rules; keep SwiftUI native animation and UIKit Core Animation as separate private implementations.

**Tech Stack:** Swift 5.10, Swift Package Manager, iOS 15, SwiftUI, UIKit, Core Animation, XCTest, DocC, XcodeGen-generated offline example.

## Global Constraints

- Keep `Package.swift` at Swift tools 5.10 and iOS 15.
- Keep one `ITextKit` product and module with zero external dependencies.
- Public names are `ITextShimmerDirection`, `ITextShimmerConfiguration`, `View.shimmerText(...)`, and `ITextShimmerLabel`; add no `IShimmerText*` compatibility declarations.
- Public configuration preserves caller values; only internal resolved values clamp or fall back.
- Keep SwiftUI and UIKit rendering native and independent; do not use `ITextPlaybackState`, `Timer`, `CADisplayLink`, `TimelineView`, `Canvas`, Metal, or per-frame package-owned Swift callbacks.
- Preserve base text layout, intrinsic sizing, hit testing, accessibility, Dynamic Type, dynamic colors, attributed text, semantic RTL behavior, Reduce Motion, and lifecycle behavior.
- Give every public declaration semantic `///` DocC covering units, defaults, ranges, invalid-value resolution, restart behavior, lifecycle, accessibility, ownership, and performance where applicable.
- Do not modify, delete, tag, publish, or archive the standalone `../IShimmerText` repository.

---

## File Structure

**Create:**

- `Sources/ITextKit/Core/ITextShimmerConfiguration.swift` — public configuration and direction plus internal resolved values.
- `Sources/ITextKit/Internal/ITextShimmerGeometry.swift` — semantic direction resolution and deterministic band positions.
- `Sources/ITextKit/Internal/ITextShimmerActivationState.swift` — pure animation eligibility rule.
- `Sources/ITextKit/SwiftUI/ITextShimmerModifier.swift` — public modifier and private native SwiftUI renderer.
- `Sources/ITextKit/UIKit/ITextShimmerLabel.swift` — UILabel subclass, mirrored highlight label, lifecycle, mask, and keyed Core Animation.
- `Tests/ITextKitCoreTests/ITextShimmerConfigurationTests.swift` — defaults and normalization.
- `Tests/ITextKitCoreTests/ITextShimmerGeometryTests.swift` — direction and band geometry.
- `Tests/ITextKitCoreTests/ITextShimmerActivationStateTests.swift` — activation conditions.
- `Tests/ITextKitSwiftUITests/ITextShimmerModifierTests.swift` — public modifier construction.
- `Tests/ITextKitUIKitTests/ITextShimmerLabelTests.swift` — public behavior and Core Animation lifecycle.
- `Sources/ITextKit/Documentation.docc/TextShimmer.md` — complete shimmer guide.

**Modify:**

- `Example/ITextKitExample/SwiftUIExampleView.swift` — visible SwiftUI shimmer sample.
- `Example/ITextKitExample/UIKitExampleViewController.swift` — visible UIKit shimmer sample.
- `Example/ITextKitExampleUITests/ITextKitExampleUITests.swift` — both shimmer entry points.
- `Example/README.md` — sample coverage description.
- `README.md` — feature, usage, behavior, accessibility, and configuration docs.
- `Sources/ITextKit/Documentation.docc/ITextKit.md` — overview and Topics entry.
- `Sources/ITextKit/Documentation.docc/PlaybackAndLifecycle.md` — distinguish shimmer switches from playback state.
- `CHANGELOG.md` — Unreleased feature entry.
- `ROADMAP.md` — remove the completed migration item and represent an empty planned list accurately.

---

### Task 1: Public Shimmer Configuration

**Files:**

- Create: `Tests/ITextKitCoreTests/ITextShimmerConfigurationTests.swift`
- Create: `Sources/ITextKit/Core/ITextShimmerConfiguration.swift`

**Interfaces:**

- Consumes: Foundation `TimeInterval`, CoreGraphics `CGFloat`.
- Produces: `ITextShimmerDirection`, `ITextShimmerConfiguration`, `ITextShimmerConfiguration.default`, and internal `ITextShimmerResolvedConfiguration`.

- [ ] **Step 1: Write the failing configuration tests**

```swift
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
```

- [ ] **Step 2: Run the focused tests and verify the interface is missing**

Run:

```bash
xcodebuild -quiet test -scheme ITextKit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ITextKitCoreTests/ITextShimmerConfigurationTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because `ITextShimmerConfiguration` and `ITextShimmerDirection` do not exist.

- [ ] **Step 3: Implement the public configuration and internal resolution**

Create `Sources/ITextKit/Core/ITextShimmerConfiguration.swift` with the exact public interface and full DocC:

```swift
import CoreGraphics
import Foundation

/// A semantic direction for a text highlight sweep.
public enum ITextShimmerDirection: Sendable, Equatable, Hashable {
    /// Travels from the leading text edge to the trailing text edge.
    case leadingToTrailing

    /// Travels from the trailing text edge to the leading text edge.
    case trailingToLeading
}

/// Configures the timing and appearance of a text highlight sweep.
public struct ITextShimmerConfiguration: Sendable, Equatable {
    /// Seconds for one complete offscreen-to-offscreen sweep.
    ///
    /// Renderers clamp finite values to `0.2...10`; non-finite values resolve
    /// to the default `1.5` seconds without changing this public value.
    public var duration: TimeInterval

    /// Highlight-band width as a fraction of the rendered text width.
    ///
    /// Renderers clamp finite values to `0.05...1`; non-finite values resolve
    /// to the default `0.28` without changing this public value.
    public var bandWidth: CGFloat

    /// Opacity multiplier applied to the highlight copy.
    ///
    /// Renderers clamp finite values to `0...1`; non-finite values resolve to
    /// the default `0.85`. A resolved value of zero disables the overlay.
    public var intensity: CGFloat

    /// Semantic direction that resolves against the current layout direction.
    ///
    /// Leading-to-trailing moves right in left-to-right interfaces and left in
    /// right-to-left interfaces. Trailing-to-leading resolves oppositely.
    public var direction: ITextShimmerDirection

    /// Creates a configuration while preserving every supplied public value.
    ///
    /// - Parameters:
    ///   - duration: Sweep duration in seconds. The default is `1.5`.
    ///   - bandWidth: Band width relative to rendered text. The default is `0.28`.
    ///   - intensity: Highlight-copy opacity multiplier. The default is `0.85`.
    ///   - direction: Semantic travel direction. The default is
    ///     ``ITextShimmerDirection/leadingToTrailing``.
    public init(
        duration: TimeInterval = 1.5,
        bandWidth: CGFloat = 0.28,
        intensity: CGFloat = 0.85,
        direction: ITextShimmerDirection = .leadingToTrailing
    ) {
        self.duration = duration
        self.bandWidth = bandWidth
        self.intensity = intensity
        self.direction = direction
    }

    /// The standard 1.5-second, 0.28-width, 0.85-intensity,
    /// leading-to-trailing highlight sweep.
    public static let `default` = ITextShimmerConfiguration()

    /// Finite, range-safe values consumed only by renderers.
    var resolved: ITextShimmerResolvedConfiguration {
        ITextShimmerResolvedConfiguration(
            duration: duration.isFinite ? min(max(duration, 0.2), 10) : Self.default.duration,
            bandWidth: bandWidth.isFinite ? min(max(bandWidth, 0.05), 1) : Self.default.bandWidth,
            intensity: intensity.isFinite ? min(max(intensity, 0), 1) : Self.default.intensity,
            direction: direction
        )
    }
}

struct ITextShimmerResolvedConfiguration: Sendable, Equatable, Hashable {
    let duration: TimeInterval
    let bandWidth: CGFloat
    let intensity: CGFloat
    let direction: ITextShimmerDirection
}
```

- [ ] **Step 4: Run the focused tests and verify they pass**

Run the Step 2 command. Expected: PASS.

- [ ] **Step 5: Commit the configuration slice**

```bash
git add Sources/ITextKit/Core/ITextShimmerConfiguration.swift \
  Tests/ITextKitCoreTests/ITextShimmerConfigurationTests.swift
git commit -m "feat: add shimmer configuration"
```

---

### Task 2: Deterministic Direction, Geometry, and Activation

**Files:**

- Create: `Tests/ITextKitCoreTests/ITextShimmerGeometryTests.swift`
- Create: `Tests/ITextKitCoreTests/ITextShimmerActivationStateTests.swift`
- Create: `Sources/ITextKit/Internal/ITextShimmerGeometry.swift`
- Create: `Sources/ITextKit/Internal/ITextShimmerActivationState.swift`

**Interfaces:**

- Consumes: `ITextShimmerDirection` and resolved intensity from Task 1.
- Produces: internal `ITextShimmerTravelDirection`, `ITextShimmerGeometry`, and `ITextShimmerActivationState.shouldAnimate(...)` for both renderers.

- [ ] **Step 1: Write failing direction and geometry tests**

```swift
import CoreGraphics
import XCTest
@testable import ITextKit

final class ITextShimmerGeometryTests: XCTestCase {
    func testSemanticDirectionResolvesAgainstLayoutDirection() {
        XCTAssertEqual(
            ITextShimmerDirection.leadingToTrailing.resolved(isRightToLeft: false),
            .leftToRight
        )
        XCTAssertEqual(
            ITextShimmerDirection.leadingToTrailing.resolved(isRightToLeft: true),
            .rightToLeft
        )
        XCTAssertEqual(
            ITextShimmerDirection.trailingToLeading.resolved(isRightToLeft: false),
            .rightToLeft
        )
        XCTAssertEqual(
            ITextShimmerDirection.trailingToLeading.resolved(isRightToLeft: true),
            .leftToRight
        )
    }

    func testBandStartsAndEndsFullyOutsideBounds() {
        let geometry = ITextShimmerGeometry(containerWidth: 200, bandFraction: 0.25)

        XCTAssertEqual(geometry.bandWidth, 50)
        XCTAssertEqual(geometry.leftOffscreenCenter, -25)
        XCTAssertEqual(geometry.rightOffscreenCenter, 225)
    }

    func testProgressClampsAndResolvesBothDirections() {
        let geometry = ITextShimmerGeometry(containerWidth: 200, bandFraction: 0.25)

        XCTAssertEqual(geometry.center(at: -1, direction: .leftToRight), -25)
        XCTAssertEqual(geometry.center(at: 0.5, direction: .leftToRight), 100)
        XCTAssertEqual(geometry.center(at: 2, direction: .leftToRight), 225)
        XCTAssertEqual(geometry.center(at: 0, direction: .rightToLeft), 225)
        XCTAssertEqual(geometry.center(at: 1, direction: .rightToLeft), -25)
    }

    func testNegativeContainerWidthResolvesToZero() {
        let geometry = ITextShimmerGeometry(containerWidth: -10, bandFraction: 0.25)

        XCTAssertEqual(geometry.containerWidth, 0)
        XCTAssertEqual(geometry.bandWidth, 0)
    }
}
```

- [ ] **Step 2: Write failing activation tests**

```swift
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
```

- [ ] **Step 3: Run the focused core tests and verify missing internal types**

```bash
xcodebuild -quiet test -scheme ITextKit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ITextKitCoreTests/ITextShimmerGeometryTests \
  -only-testing:ITextKitCoreTests/ITextShimmerActivationStateTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because the geometry and activation types do not exist.

- [ ] **Step 4: Implement semantic direction and geometry**

Create `Sources/ITextKit/Internal/ITextShimmerGeometry.swift`:

```swift
import CoreGraphics

extension ITextShimmerDirection {
    func resolved(isRightToLeft: Bool) -> ITextShimmerTravelDirection {
        switch (self, isRightToLeft) {
        case (.leadingToTrailing, false), (.trailingToLeading, true):
            return .leftToRight
        case (.leadingToTrailing, true), (.trailingToLeading, false):
            return .rightToLeft
        }
    }
}

enum ITextShimmerTravelDirection: Sendable, Equatable, Hashable {
    case leftToRight
    case rightToLeft
}

struct ITextShimmerGeometry: Sendable, Equatable {
    let containerWidth: CGFloat
    let bandWidth: CGFloat

    init(containerWidth: CGFloat, bandFraction: CGFloat) {
        self.containerWidth = max(containerWidth, 0)
        bandWidth = self.containerWidth * bandFraction
    }

    var leftOffscreenCenter: CGFloat { -bandWidth / 2 }
    var rightOffscreenCenter: CGFloat { containerWidth + bandWidth / 2 }

    func center(at progress: CGFloat, direction: ITextShimmerTravelDirection) -> CGFloat {
        let value = min(max(progress, 0), 1)
        let start = direction == .leftToRight ? leftOffscreenCenter : rightOffscreenCenter
        let end = direction == .leftToRight ? rightOffscreenCenter : leftOffscreenCenter
        return start + (end - start) * value
    }
}
```

Add semantic internal DocC for why direction is resolved late and why the band begins and ends fully outside the text bounds.

- [ ] **Step 5: Implement the pure activation rule**

Create `Sources/ITextKit/Internal/ITextShimmerActivationState.swift`:

```swift
import CoreGraphics

enum ITextShimmerActivationState {
    static func shouldAnimate(
        isRequested: Bool,
        hasContent: Bool,
        hasBounds: Bool,
        isInWindow: Bool,
        reduceMotion: Bool,
        intensity: CGFloat
    ) -> Bool {
        isRequested &&
            hasContent &&
            hasBounds &&
            isInWindow &&
            !reduceMotion &&
            intensity > 0
    }
}
```

- [ ] **Step 6: Run the focused tests and verify they pass**

Run the Step 3 command. Expected: PASS.

- [ ] **Step 7: Commit deterministic shimmer rules**

```bash
git add Sources/ITextKit/Internal/ITextShimmerGeometry.swift \
  Sources/ITextKit/Internal/ITextShimmerActivationState.swift \
  Tests/ITextKitCoreTests/ITextShimmerGeometryTests.swift \
  Tests/ITextKitCoreTests/ITextShimmerActivationStateTests.swift
git commit -m "feat: add shimmer geometry rules"
```

---

### Task 3: SwiftUI Shimmer Modifier

**Files:**

- Create: `Tests/ITextKitSwiftUITests/ITextShimmerModifierTests.swift`
- Create: `Sources/ITextKit/SwiftUI/ITextShimmerModifier.swift`

**Interfaces:**

- Consumes: `ITextShimmerConfiguration.resolved`, `ITextShimmerDirection.resolved(isRightToLeft:)`, and `ITextShimmerGeometry`.
- Produces: `View.shimmerText(isActive:configuration:highlight:) -> some View`.

- [ ] **Step 1: Write failing public interface construction tests**

```swift
import SwiftUI
import XCTest
@testable import ITextKit

@MainActor
final class ITextShimmerModifierTests: XCTestCase {
    func testModifierConstructsForPlainAttributedAndMultilineText() {
        let plain = Text("Working…")
            .foregroundStyle(.secondary)
            .shimmerText()

        var attributed = AttributedString("Rich shimmer")
        attributed.font = .headline.bold()
        attributed.foregroundColor = .purple
        let rich = Text(attributed)
            .shimmerText(
                isActive: true,
                configuration: .init(
                    duration: 2,
                    bandWidth: 0.4,
                    intensity: 0.7,
                    direction: .trailingToLeading
                ),
                highlight: .primary
            )

        let multiline = Text("A longer status\nthat spans lines")
            .lineLimit(nil)
            .shimmerText(isActive: false)

        _ = plain
        _ = rich
        _ = multiline
    }
}
```

- [ ] **Step 2: Run the focused test and verify the modifier is missing**

```bash
xcodebuild -quiet test -scheme ITextKit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ITextKitSwiftUITests/ITextShimmerModifierTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because `shimmerText` does not exist.

- [ ] **Step 3: Implement the native SwiftUI modifier**

Create `Sources/ITextKit/SwiftUI/ITextShimmerModifier.swift` with these concrete elements:

```swift
import SwiftUI

public extension View {
    /// Adds a repeating highlight sweep to rendered text.
    ///
    /// Apply text styling before this modifier and outer layout or decoration
    /// after it, so only text enters the highlight copy. The original remains
    /// the sole layout,
    /// hit-testing, and accessibility owner. The overlay is omitted when
    /// inactive, under Reduce Motion, or at zero resolved intensity.
    /// Deactivation discards progress, so later reactivation starts a complete
    /// sweep. Semantic direction follows the current layout direction. Native
    /// SwiftUI animation advances frames without a package timer or display link.
    ///
    /// - Parameters:
    ///   - isActive: Whether the caller requests shimmer. The default is `true`.
    ///   - configuration: Sweep timing and appearance. The default is
    ///     ``ITextShimmerConfiguration/default``.
    ///   - highlight: Dynamic highlight color. The default is `Color.primary`.
    /// - Returns: The original content with an optional noninteractive overlay.
    func shimmerText(
        isActive: Bool = true,
        configuration: ITextShimmerConfiguration = .default,
        highlight: Color = .primary
    ) -> some View {
        modifier(ITextShimmerModifier(
            isActive: isActive,
            configuration: configuration,
            highlight: highlight
        ))
    }
}

private struct ITextShimmerModifier: ViewModifier {
    let isActive: Bool
    let configuration: ITextShimmerConfiguration
    let highlight: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        let resolved = configuration.resolved
        let isRightToLeft = layoutDirection == .rightToLeft

        return content.overlay {
            if isActive, !reduceMotion, resolved.intensity > 0 {
                ITextShimmerAnimatedOverlay(
                    content: content,
                    configuration: resolved,
                    highlight: highlight,
                    direction: resolved.direction.resolved(isRightToLeft: isRightToLeft)
                )
                .id(ITextShimmerAnimationIdentity(
                    configuration: resolved,
                    isRightToLeft: isRightToLeft
                ))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
}

private struct ITextShimmerAnimationIdentity: Hashable {
    let configuration: ITextShimmerResolvedConfiguration
    let isRightToLeft: Bool
}

private struct ITextShimmerAnimatedOverlay<Content: View>: View {
    let content: Content
    let configuration: ITextShimmerResolvedConfiguration
    let highlight: Color
    let direction: ITextShimmerTravelDirection

    @State private var progress: CGFloat = 0

    var body: some View {
        content
            .foregroundStyle(highlight.opacity(Double(configuration.intensity)))
            .mask {
                GeometryReader { proxy in
                    let geometry = ITextShimmerGeometry(
                        containerWidth: proxy.size.width,
                        bandFraction: configuration.bandWidth
                    )

                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.35),
                            .black,
                            .black.opacity(0.35),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.bandWidth, height: proxy.size.height)
                    .position(
                        x: geometry.center(at: progress, direction: direction),
                        y: proxy.size.height / 2
                    )
                }
            }
            .onAppear {
                progress = 0
                withAnimation(
                    .linear(duration: configuration.duration)
                        .repeatForever(autoreverses: false)
                ) {
                    progress = 1
                }
            }
    }
}
```

- [ ] **Step 4: Run the focused test and verify it passes**

Run the Step 2 command. Expected: PASS.

- [ ] **Step 5: Commit the SwiftUI slice**

```bash
git add Sources/ITextKit/SwiftUI/ITextShimmerModifier.swift \
  Tests/ITextKitSwiftUITests/ITextShimmerModifierTests.swift
git commit -m "feat: add SwiftUI text shimmer"
```

---

### Task 4: UIKit Shimmer Label

**Files:**

- Create: `Tests/ITextKitUIKitTests/ITextShimmerLabelTests.swift`
- Create: `Sources/ITextKit/UIKit/ITextShimmerLabel.swift`

**Interfaces:**

- Consumes: Task 1 configuration and Task 2 geometry and activation rules.
- Produces: `@MainActor public final class ITextShimmerLabel: UILabel` with `isShimmering`, `configuration`, and `highlightColor`.

- [ ] **Step 1: Write failing public defaults and content synchronization tests**

```swift
import UIKit
import XCTest
@testable import ITextKit

@MainActor
final class ITextShimmerLabelTests: XCTestCase {
    func testPublicDefaultsAndPlainTextSynchronization() throws {
        let label = ITextShimmerLabel()
        label.text = "Working…"
        label.font = .preferredFont(forTextStyle: .headline)
        label.numberOfLines = 0
        label.textAlignment = .center

        let overlay = try XCTUnwrap(label.subviews.compactMap { $0 as? UILabel }.first)
        XCTAssertEqual(label.configuration, .default)
        XCTAssertEqual(label.highlightColor, .label)
        XCTAssertFalse(label.isShimmering)
        XCTAssertEqual(overlay.text, label.text)
        XCTAssertEqual(overlay.font, label.font)
        XCTAssertEqual(overlay.numberOfLines, 0)
        XCTAssertEqual(overlay.textAlignment, .center)
        XCTAssertFalse(overlay.isAccessibilityElement)
        XCTAssertFalse(overlay.isUserInteractionEnabled)
    }

    func testAttributedTextCopyPreservesInputAndOverridesOnlyOverlayForeground() throws {
        let source = NSAttributedString(
            string: "Working…",
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.systemPink,
                .kern: 1.5
            ]
        )
        let label = ITextShimmerLabel()
        label.configuration = .init(intensity: 1)
        label.highlightColor = .systemYellow
        label.attributedText = source

        let overlay = try XCTUnwrap(label.subviews.compactMap { $0 as? UILabel }.first)
        let overlayText = try XCTUnwrap(overlay.attributedText)
        XCTAssertEqual(
            source.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor,
            .systemPink
        )
        XCTAssertEqual(
            overlayText.attribute(.kern, at: 0, effectiveRange: nil) as? NSNumber,
            1.5
        )
        let traits = UITraitCollection(userInterfaceStyle: .light)
        let color = try XCTUnwrap(
            overlayText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        )
        XCTAssertEqual(
            color.resolvedColor(with: traits).cgColor,
            UIColor.systemYellow.resolvedColor(with: traits).cgColor
        )
    }

    func testDrawingPropertiesAndIntrinsicSizeStaySynchronized() throws {
        let label = ITextShimmerLabel()
        label.text = "A multiline shimmer label"
        label.numberOfLines = 0
        label.lineBreakMode = .byTruncatingMiddle
        label.baselineAdjustment = .alignCenters
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.allowsDefaultTighteningForTruncation = true
        label.preferredMaxLayoutWidth = 240
        label.adjustsFontForContentSizeCategory = true

        let overlay = try XCTUnwrap(label.subviews.compactMap { $0 as? UILabel }.first)
        XCTAssertEqual(overlay.numberOfLines, label.numberOfLines)
        XCTAssertEqual(overlay.lineBreakMode, label.lineBreakMode)
        XCTAssertEqual(overlay.baselineAdjustment, label.baselineAdjustment)
        XCTAssertEqual(overlay.adjustsFontSizeToFitWidth, label.adjustsFontSizeToFitWidth)
        XCTAssertEqual(overlay.minimumScaleFactor, label.minimumScaleFactor)
        XCTAssertEqual(
            overlay.allowsDefaultTighteningForTruncation,
            label.allowsDefaultTighteningForTruncation
        )
        XCTAssertEqual(overlay.preferredMaxLayoutWidth, label.preferredMaxLayoutWidth)
        XCTAssertEqual(
            overlay.adjustsFontForContentSizeCategory,
            label.adjustsFontForContentSizeCategory
        )
        XCTAssertEqual(label.intrinsicContentSize, UILabel.copyingLayout(from: label).intrinsicContentSize)
    }
}

private extension UILabel {
    static func copyingLayout(from source: UILabel) -> UILabel {
        let copy = UILabel()
        if let attributedText = source.attributedText {
            copy.attributedText = attributedText
        } else {
            copy.text = source.text
        }
        copy.font = source.font
        copy.numberOfLines = source.numberOfLines
        copy.lineBreakMode = source.lineBreakMode
        copy.preferredMaxLayoutWidth = source.preferredMaxLayoutWidth
        return copy
    }
}
```

- [ ] **Step 2: Write failing idempotency and lifecycle tests**

Add these methods to `ITextShimmerLabelTests`:

```swift
func testActivationAddsExactlyOneGradientMaskAndAnimation() throws {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
    let controller = UIViewController()
    window.rootViewController = controller
    let label = ITextShimmerLabel(frame: CGRect(x: 20, y: 20, width: 200, height: 40))
    label.text = "Working…"
    controller.view.addSubview(label)
    window.makeKeyAndVisible()

    label.isShimmering = true
    label.layoutIfNeeded()
    label.isShimmering = true
    label.layoutIfNeeded()

    let overlay = try XCTUnwrap(label.subviews.compactMap { $0 as? UILabel }.first)
    let gradient = try XCTUnwrap(overlay.layer.mask as? CAGradientLayer)
    XCTAssertEqual(gradient.animationKeys(), ["ITextKit.shimmer.position"])
}

func testBoundsAndConfigurationChangesReplaceAnimation() throws {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 200))
    let controller = UIViewController()
    window.rootViewController = controller
    let label = ITextShimmerLabel(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
    label.text = "Working…"
    controller.view.addSubview(label)
    window.makeKeyAndVisible()
    label.isShimmering = true
    label.layoutIfNeeded()

    let overlay = try XCTUnwrap(label.subviews.compactMap { $0 as? UILabel }.first)
    let first = try XCTUnwrap(
        ((overlay.layer.mask?.animation(forKey: "ITextKit.shimmer.position") as? CABasicAnimation)?
            .toValue as? NSNumber)?.doubleValue
    )

    label.frame.size.width = 200
    label.configuration = .init(duration: 2.25)
    label.layoutIfNeeded()

    let animation = try XCTUnwrap(
        overlay.layer.mask?.animation(forKey: "ITextKit.shimmer.position") as? CABasicAnimation
    )
    let second = try XCTUnwrap((animation.toValue as? NSNumber)?.doubleValue)
    XCTAssertGreaterThan(second, first)
    XCTAssertEqual(animation.duration, 2.25)
    XCTAssertEqual(overlay.layer.mask?.animationKeys(), ["ITextKit.shimmer.position"])
}

func testDeactivationWindowRemovalAndMissingContentRemoveAnimation() throws {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
    let controller = UIViewController()
    window.rootViewController = controller
    let label = ITextShimmerLabel(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
    controller.view.addSubview(label)
    window.makeKeyAndVisible()
    label.isShimmering = true
    label.layoutIfNeeded()

    let overlay = try XCTUnwrap(label.subviews.compactMap { $0 as? UILabel }.first)
    XCTAssertNil(overlay.layer.mask)

    label.text = "Working…"
    label.layoutIfNeeded()
    XCTAssertNotNil(overlay.layer.mask)

    label.isShimmering = false
    XCTAssertNil(overlay.layer.mask)
    XCTAssertTrue(overlay.isHidden)

    label.isShimmering = true
    label.layoutIfNeeded()
    label.removeFromSuperview()
    XCTAssertNil(overlay.layer.mask)
}
```

- [ ] **Step 3: Run the focused UIKit tests and verify the class is missing**

```bash
xcodebuild -quiet test -scheme ITextKit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ITextKitUIKitTests/ITextShimmerLabelTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because `ITextShimmerLabel` does not exist.

- [ ] **Step 4: Implement the UILabel seam and property synchronization**

Create `Sources/ITextKit/UIKit/ITextShimmerLabel.swift`. The public declarations and state are:

```swift
import UIKit

/// A UILabel that can render a restart-on-reactivation highlight sweep while
/// preserving native text layout, intrinsic sizing, and accessibility.
@MainActor
public final class ITextShimmerLabel: UILabel {
    /// Whether the caller requests an active sweep. Reactivation restarts it.
    public var isShimmering = false {
        didSet {
            guard isShimmering != oldValue else { return }
            reconcileAnimation()
        }
    }

    /// Timing, band-width, intensity, and semantic-direction values.
    public var configuration: ITextShimmerConfiguration = .default {
        didSet {
            guard configuration != oldValue else { return }
            synchronizeOverlayContent()
            rebuildAnimationIfNeeded()
        }
    }

    /// Dynamic color used only by the private highlight copy.
    public var highlightColor: UIColor = .label {
        didSet { synchronizeOverlayContent() }
    }

    private let shimmerOverlayLabel: UILabel
    private var lastAnimatedBounds: CGRect = .null
    private var lastTravelDirection: ITextShimmerTravelDirection?
    private let animationKey = "ITextKit.shimmer.position"

    public override init(frame: CGRect) {
        shimmerOverlayLabel = UILabel()
        super.init(frame: frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        shimmerOverlayLabel = UILabel()
        super.init(coder: coder)
        setUp()
    }
}
```

Add these exact native-property and lifecycle overrides inside the class:

```swift
deinit {
    NotificationCenter.default.removeObserver(self)
}

public override var text: String? {
    didSet {
        synchronizeOverlayContent()
        reconcileAnimation()
    }
}

public override var attributedText: NSAttributedString? {
    didSet {
        synchronizeOverlayContent()
        reconcileAnimation()
    }
}

public override var font: UIFont! {
    didSet { synchronizeOverlayContent() }
}

public override var numberOfLines: Int {
    didSet { shimmerOverlayLabel.numberOfLines = numberOfLines }
}

public override var lineBreakMode: NSLineBreakMode {
    didSet { shimmerOverlayLabel.lineBreakMode = lineBreakMode }
}

public override var textAlignment: NSTextAlignment {
    didSet { shimmerOverlayLabel.textAlignment = textAlignment }
}

public override var baselineAdjustment: UIBaselineAdjustment {
    didSet { shimmerOverlayLabel.baselineAdjustment = baselineAdjustment }
}

public override var adjustsFontSizeToFitWidth: Bool {
    didSet {
        shimmerOverlayLabel.adjustsFontSizeToFitWidth = adjustsFontSizeToFitWidth
    }
}

public override var minimumScaleFactor: CGFloat {
    didSet { shimmerOverlayLabel.minimumScaleFactor = minimumScaleFactor }
}

public override var allowsDefaultTighteningForTruncation: Bool {
    didSet {
        shimmerOverlayLabel.allowsDefaultTighteningForTruncation =
            allowsDefaultTighteningForTruncation
    }
}

public override var preferredMaxLayoutWidth: CGFloat {
    didSet {
        shimmerOverlayLabel.preferredMaxLayoutWidth = preferredMaxLayoutWidth
    }
}

public override var adjustsFontForContentSizeCategory: Bool {
    didSet {
        shimmerOverlayLabel.adjustsFontForContentSizeCategory =
            adjustsFontForContentSizeCategory
    }
}

public override func layoutSubviews() {
    super.layoutSubviews()
    shimmerOverlayLabel.frame = bounds
    reconcileAnimation()
}

public override func didMoveToWindow() {
    super.didMoveToWindow()
    reconcileAnimation()
}

public override func traitCollectionDidChange(
    _ previousTraitCollection: UITraitCollection?
) {
    super.traitCollectionDidChange(previousTraitCollection)
    reconcileAnimation()
}
```

Add setup and environment observation with these exact responsibilities:

```swift
private func setUp() {
    shimmerOverlayLabel.isHidden = true
    shimmerOverlayLabel.isAccessibilityElement = false
    shimmerOverlayLabel.isUserInteractionEnabled = false
    addSubview(shimmerOverlayLabel)
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleEnvironmentChange),
        name: UIApplication.willEnterForegroundNotification,
        object: nil
    )
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleEnvironmentChange),
        name: UIAccessibility.reduceMotionStatusDidChangeNotification,
        object: nil
    )
    synchronizeOverlayContent()
}

@objc private func handleEnvironmentChange() {
    reconcileAnimation()
}
```

The attributed branch of `synchronizeOverlayContent()` must copy and replace only the private copy's foreground:

```swift
if let attributedText {
    let copy = NSMutableAttributedString(attributedString: attributedText)
    copy.addAttribute(
        .foregroundColor,
        value: highlightColor.withAlphaComponent(configuration.resolved.intensity),
        range: NSRange(location: 0, length: copy.length)
    )
    shimmerOverlayLabel.attributedText = copy
} else {
    shimmerOverlayLabel.attributedText = nil
    shimmerOverlayLabel.text = text
    shimmerOverlayLabel.textColor = highlightColor.withAlphaComponent(
        configuration.resolved.intensity
    )
}

shimmerOverlayLabel.font = font
shimmerOverlayLabel.numberOfLines = numberOfLines
shimmerOverlayLabel.lineBreakMode = lineBreakMode
shimmerOverlayLabel.textAlignment = textAlignment
shimmerOverlayLabel.baselineAdjustment = baselineAdjustment
shimmerOverlayLabel.adjustsFontSizeToFitWidth = adjustsFontSizeToFitWidth
shimmerOverlayLabel.minimumScaleFactor = minimumScaleFactor
shimmerOverlayLabel.allowsDefaultTighteningForTruncation =
    allowsDefaultTighteningForTruncation
shimmerOverlayLabel.preferredMaxLayoutWidth = preferredMaxLayoutWidth
shimmerOverlayLabel.adjustsFontForContentSizeCategory =
    adjustsFontForContentSizeCategory
```

- [ ] **Step 5: Implement idempotent activation and keyed Core Animation**

Use the shared activation rule and exact mask shape:

```swift
private func reconcileAnimation() {
    let resolved = configuration.resolved
    let shouldAnimate = ITextShimmerActivationState.shouldAnimate(
        isRequested: isShimmering,
        hasContent: hasTextContent,
        hasBounds: !bounds.isEmpty,
        isInWindow: window != nil,
        reduceMotion: UIAccessibility.isReduceMotionEnabled,
        intensity: resolved.intensity
    )
    guard shouldAnimate else {
        stopAnimation()
        return
    }

    let direction = resolved.direction.resolved(
        isRightToLeft: effectiveUserInterfaceLayoutDirection == .rightToLeft
    )
    let mask = shimmerOverlayLabel.layer.mask
    let hasAnimation = mask?.animation(forKey: animationKey) != nil
    guard mask == nil || !hasAnimation ||
            lastAnimatedBounds != bounds ||
            lastTravelDirection != direction else { return }

    startAnimation(configuration: resolved, direction: direction)
}

private func startAnimation(
    configuration: ITextShimmerResolvedConfiguration,
    direction: ITextShimmerTravelDirection
) {
    stopAnimation()
    synchronizeOverlayContent()
    let geometry = ITextShimmerGeometry(
        containerWidth: bounds.width,
        bandFraction: configuration.bandWidth
    )
    let gradient = CAGradientLayer()
    gradient.startPoint = CGPoint(x: 0, y: 0.5)
    gradient.endPoint = CGPoint(x: 1, y: 0.5)
    gradient.colors = [
        UIColor.clear.cgColor,
        UIColor.black.withAlphaComponent(0.35).cgColor,
        UIColor.black.cgColor,
        UIColor.black.withAlphaComponent(0.35).cgColor,
        UIColor.clear.cgColor
    ]
    gradient.locations = [0, 0.25, 0.5, 0.75, 1]
    gradient.bounds = CGRect(x: 0, y: 0, width: geometry.bandWidth, height: bounds.height)
    gradient.position = CGPoint(
        x: geometry.center(at: 1, direction: direction),
        y: bounds.midY
    )
    shimmerOverlayLabel.layer.mask = gradient

    let animation = CABasicAnimation(keyPath: "position.x")
    animation.fromValue = geometry.center(at: 0, direction: direction)
    animation.toValue = geometry.center(at: 1, direction: direction)
    animation.duration = configuration.duration
    animation.repeatCount = .infinity
    animation.timingFunction = CAMediaTimingFunction(name: .linear)
    gradient.add(animation, forKey: animationKey)

    shimmerOverlayLabel.isHidden = false
    lastAnimatedBounds = bounds
    lastTravelDirection = direction
}

private func stopAnimation() {
    shimmerOverlayLabel.layer.mask?.removeAnimation(forKey: animationKey)
    shimmerOverlayLabel.layer.mask = nil
    shimmerOverlayLabel.isHidden = true
    lastAnimatedBounds = .null
    lastTravelDirection = nil
}
```

Wrap gradient bounds, position, and mask assignment in a disabled-actions `CATransaction` so property writes do not create implicit animations.

- [ ] **Step 6: Run the focused tests and verify they pass**

Run the Step 3 command. Expected: PASS.

- [ ] **Step 7: Commit the UIKit slice**

```bash
git add Sources/ITextKit/UIKit/ITextShimmerLabel.swift \
  Tests/ITextKitUIKitTests/ITextShimmerLabelTests.swift
git commit -m "feat: add UIKit text shimmer label"
```

---

### Task 5: Offline Example and UI Coverage

**Files:**

- Modify: `Example/ITextKitExample/SwiftUIExampleView.swift`
- Modify: `Example/ITextKitExample/UIKitExampleViewController.swift`
- Modify: `Example/ITextKitExampleUITests/ITextKitExampleUITests.swift`
- Modify: `Example/README.md`

**Interfaces:**

- Consumes: `.shimmerText()` and `ITextShimmerLabel` from Tasks 3 and 4.
- Produces: visible, accessible SwiftUI and UIKit example entries named `SwiftUI shimmer` and `UIKit shimmer`.

- [ ] **Step 1: Add failing Example UI assertions**

Append to the SwiftUI test after the attributed-marquee assertions:

```swift
app.swipeUp()
XCTAssertTrue(app.staticTexts["SwiftUI shimmer"].waitForExistence(timeout: 2))
keepScreenshot(of: app, named: "SwiftUI Shimmer")
```

Append to the UIKit test after the attributed-marquee assertions:

```swift
app.swipeUp()
XCTAssertTrue(app.staticTexts["UIKit shimmer"].waitForExistence(timeout: 2))
keepScreenshot(of: app, named: "UIKit Shimmer")
```

- [ ] **Step 2: Run Example UI tests and verify the labels are missing**

```bash
xcodebuild -quiet test \
  -project Example/ITextKitExample.xcodeproj \
  -scheme ITextKitExample \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because both shimmer texts are absent.

- [ ] **Step 3: Add the SwiftUI example**

Insert this section after the attributed marquee and before the typewriter replay button:

```swift
sectionTitle("Text shimmer")

Text("SwiftUI shimmer")
    .font(.headline)
    .foregroundStyle(.secondary)
    .shimmerText(
        configuration: .init(
            duration: 1.5,
            bandWidth: 0.28,
            intensity: 0.85,
            direction: .leadingToTrailing
        ),
        highlight: .primary
    )
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Color.mint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
```

Typography and foreground precede `.shimmerText()`. Outer layout, padding, and background follow it so only text enters the animated copy.

- [ ] **Step 4: Add the UIKit example**

Add a stored label:

```swift
private let shimmerLabel = ITextShimmerLabel()
```

Configure it in `configureContent()` before creating the stack:

```swift
shimmerLabel.text = "UIKit shimmer"
shimmerLabel.font = .preferredFont(forTextStyle: .headline)
shimmerLabel.textColor = .secondaryLabel
shimmerLabel.highlightColor = .label
shimmerLabel.adjustsFontForContentSizeCategory = true
shimmerLabel.isShimmering = true
```

Insert `heading("Text shimmer")` and `card(containing: shimmerLabel, color: .systemMint)` after the attributed marquee and before the typewriter replay button.

- [ ] **Step 5: Update Example README with exact behavior**

State that both tabs include a text shimmer sample, SwiftUI uses the modifier, UIKit uses `ITextShimmerLabel`, both preserve base accessibility, and shimmer is controlled by request switches rather than `ITextPlaybackState`.

- [ ] **Step 6: Run Example UI tests and verify they pass**

Run the Step 2 command. Expected: PASS, including existing rotator, marquee, and typewriter assertions.

- [ ] **Step 7: Commit the Example slice**

```bash
git add Example/ITextKitExample/SwiftUIExampleView.swift \
  Example/ITextKitExample/UIKitExampleViewController.swift \
  Example/ITextKitExampleUITests/ITextKitExampleUITests.swift \
  Example/README.md
git commit -m "test: demonstrate text shimmer"
```

---

### Task 6: README, DocC, Changelog, and Roadmap

**Files:**

- Modify: `README.md`
- Modify: `Sources/ITextKit/Documentation.docc/ITextKit.md`
- Create: `Sources/ITextKit/Documentation.docc/TextShimmer.md`
- Modify: `Sources/ITextKit/Documentation.docc/PlaybackAndLifecycle.md`
- Modify: `CHANGELOG.md`
- Modify: `ROADMAP.md`

**Interfaces:**

- Consumes: the final public interface and verified behavior from Tasks 1 through 5.
- Produces: caller-facing documentation that exactly matches implementation and no longer lists shimmer as planned work.

- [ ] **Step 1: Add the root README feature and usage section**

Add the feature bullets:

```markdown
- `.shimmerText(...)` adds a native SwiftUI highlight sweep without replacing the original text
- `ITextShimmerLabel` adds the same treatment to a native UIKit label
```

Add a `## Text Shimmer` section containing these exact entry examples:

```swift
Text("Working…")
    .font(.headline)
    .foregroundStyle(.secondary)
    .shimmerText()
```

```swift
let label = ITextShimmerLabel()
label.text = "Working…"
label.textColor = .secondaryLabel
label.highlightColor = .label
label.isShimmering = true
```

Document modifier ordering, configuration defaults and resolution, restart-on-reactivation behavior, semantic RTL, multiline band behavior, Reduce Motion, dynamic colors, attributed-text copying, accessibility, and native-animation performance.

- [ ] **Step 2: Add the DocC shimmer guide and overview topics**

Create `TextShimmer.md` with sections `Overview`, `SwiftUI`, `UIKit`, `Configuration Resolution`, `Accessibility and Lifecycle`, and `Rendering`. Use symbol links for `ITextShimmerConfiguration`, `ITextShimmerDirection`, and `ITextShimmerLabel`, plus the same confirmed call sites.

Add this Topics group to `ITextKit.md`:

```markdown
### Shimmer

- <doc:TextShimmer>
- ``ITextShimmerLabel``
- ``ITextShimmerConfiguration``
- ``ITextShimmerDirection``
```

Update the overview sentence so rotation, marquee, typewriter, and shimmer are all named.

- [ ] **Step 3: Document the separate lifecycle contract**

Append `## Shimmer Request Switches` to `PlaybackAndLifecycle.md`. State that `.shimmerText(isActive:)` and `ITextShimmerLabel.isShimmering` request a repeating decoration, deactivation discards progress, reactivation starts a complete sweep, Reduce Motion displays only base text, and shimmer does not use `ITextPlaybackState`.

- [ ] **Step 4: Update changelog and completed roadmap**

Prepend this changelog section:

```markdown
## Unreleased

### Added

- SwiftUI `.shimmerText(...)` and UIKit `ITextShimmerLabel` native text-highlight sweeps.
- Semantic directions, configuration normalization, rich-text preservation, Reduce Motion, lifecycle, accessibility, example, and regression coverage for shimmer.
```

Replace the roadmap body after the title with:

```markdown
ITextKit currently provides plain and attributed rotation, marquee movement, one-shot typewriter presentation, and native text shimmer for SwiftUI and UIKit.

## Planned

No additional capabilities are currently planned. Future capabilities will be documented here before placeholder interfaces are introduced.
```

- [ ] **Step 5: Build DocC and verify every public shimmer symbol resolves**

```bash
xcodebuild -quiet docbuild -scheme ITextKit \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: PASS with no unresolved shimmer symbol warnings.

- [ ] **Step 6: Search documentation for stale interface names**

```bash
rg -n 'IShimmerText(Configuration|Direction|Label)|shimmerConfiguration|shimmerHighlightColor' \
  Sources Tests Example README.md CHANGELOG.md ROADMAP.md
```

Expected: no matches. The design and plan documents may name the standalone package as migration context.

- [ ] **Step 7: Commit documentation and roadmap completion**

```bash
git add README.md CHANGELOG.md ROADMAP.md \
  Sources/ITextKit/Documentation.docc/ITextKit.md \
  Sources/ITextKit/Documentation.docc/TextShimmer.md \
  Sources/ITextKit/Documentation.docc/PlaybackAndLifecycle.md
git commit -m "docs: document text shimmer"
```

---

### Task 7: Full Verification and Completion Audit

**Files:**

- Verify all files changed by Tasks 1 through 6.
- Verify but do not modify: `../IShimmerText`.

**Interfaces:**

- Consumes: the complete migrated feature.
- Produces: command-backed evidence for every completion criterion in the design specification.

- [ ] **Step 1: Validate the manifest**

```bash
swift package dump-package
```

Expected: valid package JSON with iOS 15, one `ITextKit` product, and no external dependencies.

- [ ] **Step 2: Run all package tests**

```bash
xcodebuild -quiet test -scheme ITextKit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: PASS for existing and new Core, SwiftUI, and UIKit tests.

- [ ] **Step 3: Run the generic iOS package build**

```bash
xcodebuild -quiet build -scheme ITextKit \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: PASS.

- [ ] **Step 4: Build DocC**

```bash
xcodebuild -quiet docbuild -scheme ITextKit \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: PASS.

- [ ] **Step 5: Build the Example application**

```bash
xcodebuild -quiet build \
  -project Example/ITextKitExample.xcodeproj \
  -scheme ITextKitExample \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: PASS.

- [ ] **Step 6: Run all Example UI tests**

```bash
xcodebuild -quiet test \
  -project Example/ITextKitExample.xcodeproj \
  -scheme ITextKitExample \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: PASS for existing controls and both shimmer integrations.

- [ ] **Step 7: Audit naming, dependencies, performance constraints, and docs**

```bash
git diff --check
rg -n 'IShimmerText(Configuration|Direction|Label)|shimmerConfiguration|shimmerHighlightColor' \
  Sources Tests Example README.md CHANGELOG.md ROADMAP.md
rg -n 'Timer\.|CADisplayLink\(|TimelineView[[:space:]]*\{|Canvas[[:space:]]*\{|import Metal' \
  Sources/ITextKit/SwiftUI/ITextShimmerModifier.swift \
  Sources/ITextKit/UIKit/ITextShimmerLabel.swift
rg -n 'ITextShimmer' README.md CHANGELOG.md ROADMAP.md \
  Sources/ITextKit/Documentation.docc Example Tests Sources/ITextKit
```

Expected: first two searches return no matches; the final search covers public interface, implementation, tests, Example, and docs. Documentation comments may name excluded technologies while promising that the implementation does not instantiate them.

- [ ] **Step 8: Verify the standalone repository remained unchanged**

```bash
git -C ../IShimmerText status --short --branch
git -C ../IShimmerText rev-parse HEAD
```

Expected: clean `main...origin/main` at `96da5f4bfe97b3f5540ecf87939952a84a7d237a` unless the user independently changed that repository after planning. Any independent change must remain untouched and be reported rather than reverted.

- [ ] **Step 9: Review the complete implementation diff**

```bash
git status --short --branch
git diff 39a4840..HEAD --stat
git diff 39a4840..HEAD --check
git log --oneline --decorate 39a4840..HEAD
```

Confirm every design criterion has direct source, test, documentation, or command evidence. Do not claim the migration complete if a required command is skipped or fails.
