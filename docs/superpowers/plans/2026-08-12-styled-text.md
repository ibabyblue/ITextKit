# ITextKit Styled Text Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add exact outward point-based text strokes plus solid and continuous linear-gradient fill/stroke to UIKit and SwiftUI, with full composition across ITextKit's existing motion and shimmer effects.

**Architecture:** Public generic style values resolve into one UIKit/Core Graphics drawing representation. A shared CoreText rendering Module owns shaping, line layout, glyph paths, decoration geometry, bounded glyph caching, and drawing plans; `ITextStyledLabel` and `ITextStyledText` are the UIKit and SwiftUI Adapters at that seam. Existing controls retain their native path when no style is supplied and delegate styled content to the shared Module.

**Tech Stack:** Swift 5.10, iOS 15+, UIKit, SwiftUI, CoreText, CoreGraphics, Core Animation, XCTest, Swift Package Manager, DocC.

## Global Constraints

- Keep `platforms: [.iOS(.v15)]`, Swift tools 5.10, one `ITextKit` library product, and no dependencies.
- `ITextStroke.width` is the final visible outward thickness in logical points; rendering uses a centered `2 * width` outline and redraws fill over its inner half.
- Support only solid and linear-gradient fill/stroke in 0.3.0; no radial/conic gradients, gradient animation, per-line gradients, or per-range ITextKit styles.
- One gradient spans the final visible text bounds, including outward stroke space and all lines.
- No production-generated text bitmap, pattern-image color, view snapshot, permanent rasterization, Canvas, Metal, or unbounded cache.
- Static styling and shimmer own no timer/display link/per-frame Swift callback; existing motion display links may update scalar presentation state only.
- Styled SwiftUI content uses `String`/`NSAttributedString` with explicit `UIFont`; do not expose a transparent modifier for arbitrary `Text` or accept SwiftUI `AttributedString` on the styled path.
- Preserve existing public initializers, unstyled rendering, attributed-text ownership, playback, scene lifecycle, RTL, Dynamic Type, Reduce Motion, and accessibility contracts.
- Public comments must document units, valid ranges, invalid-value fallbacks, RTL behavior, Dynamic Type ownership, and SwiftUI modifier ordering.
- The automated test gate is the iOS Simulator package scheme. Host `swift test` is not valid for this UIKit package.
- Do not publish 0.3.0 until the physical-device performance gates in the approved design pass and their evidence is recorded.

## File Map

New public value files:

- `Sources/ITextKit/Core/ITextLinearGradient.swift` — gradient points, stops, validation, and RTL resolution.
- `Sources/ITextKit/Core/ITextStyle.swift` — paint, stroke, style, UIKit/SwiftUI type aliases, and platform paint resolution.

New internal rendering files:

- `Sources/ITextKit/Internal/StyledText/ITextAttributedContent.swift` — immutable supported-attribute normalization.
- `Sources/ITextKit/Internal/StyledText/ITextGlyphPathCache.swift` — bounded glyph-path cache and injectable internal seam.
- `Sources/ITextKit/Internal/StyledText/ITextLayoutResult.swift` — immutable layout, glyph, fallback, and decoration records.
- `Sources/ITextKit/Internal/StyledText/ITextLayoutEngine.swift` — CoreText shaping, wrapping, truncation, alignment, scaling, and baselines.
- `Sources/ITextKit/Internal/StyledText/ITextDrawingPlan.swift` — resolved fills/strokes and direct Core Graphics drawing.
- `Sources/ITextKit/Internal/StyledText/ITextDrawingLayer.swift` — retained drawing-plan host used by both Adapters.

New public Adapter files:

- `Sources/ITextKit/UIKit/ITextStyledLabel.swift` — UILabel-compatible styled rendering and sizing.
- `Sources/ITextKit/SwiftUI/ITextStyledText.swift` — SwiftUI view and private `UIViewRepresentable` bridge.
- `Sources/ITextKit/SwiftUI/ITextSwiftUIContent.swift` — internal native/styled content enum shared by motion views.

Existing integration files:

- `Sources/ITextKit/UIKit/ITextRotatorView.swift`
- `Sources/ITextKit/UIKit/ITextMarqueeView.swift`
- `Sources/ITextKit/UIKit/ITextTypewriterView.swift`
- `Sources/ITextKit/UIKit/ITextShimmerLabel.swift`
- `Sources/ITextKit/SwiftUI/ITextRotator.swift`
- `Sources/ITextKit/SwiftUI/ITextMarquee.swift`
- `Sources/ITextKit/SwiftUI/ITextTypewriter.swift`
- `Sources/ITextKit/SwiftUI/ITextShimmerModifier.swift`

New focused tests:

- `Tests/ITextKitCoreTests/ITextStyleTests.swift`
- `Tests/ITextKitCoreTests/ITextGlyphPathCacheTests.swift`
- `Tests/ITextKitCoreTests/ITextLayoutEngineTests.swift`
- `Tests/ITextKitUIKitTests/ITextDrawingPlanTests.swift`
- `Tests/ITextKitUIKitTests/ITextStyledLabelTests.swift`
- `Tests/ITextKitUIKitTests/ITextStyledTextVisualTests.swift`
- `Tests/ITextKitUIKitTests/ITextStyledTextPerformanceTests.swift`
- `Tests/ITextKitSwiftUITests/ITextStyledTextTests.swift`

Documentation and release files:

- `README.md`
- `ROADMAP.md`
- `Sources/ITextKit/Documentation.docc/ITextKit.md`
- `Sources/ITextKit/Documentation.docc/AttributedText.md`
- `Sources/ITextKit/Documentation.docc/TextShimmer.md`
- `Sources/ITextKit/Documentation.docc/StyledText.md`
- `docs/performance/0.3.0-styled-text.md`

---

### Task 1: Public Style Values and Resolution

**Files:**

- Create: `Sources/ITextKit/Core/ITextLinearGradient.swift`
- Create: `Sources/ITextKit/Core/ITextStyle.swift`
- Create: `Tests/ITextKitCoreTests/ITextStyleTests.swift`

**Interfaces:**

- Consumes: `CGFloat`, UIKit `UIColor`, and SwiftUI `Color`.
- Produces: `ITextGradientPoint`, `ITextGradientStop<ColorValue>`, `ITextLinearGradient<ColorValue>`, `ITextPaint<ColorValue>`, `ITextStroke<ColorValue>`, `ITextStyle<ColorValue>`, `ITextUIKitStyle`, and `ITextSwiftUIStyle`.
- Produces internally: `_ITextResolvedGradient<ColorValue>`, `_ITextResolvedPaint<ColorValue>`, `_ITextResolvedStroke<ColorValue>`, and `_ITextResolvedStyle<ColorValue>`.

- [ ] **Step 1: Write failing tests for public preservation and invalid-value resolution**

Create tests with these exact expectations:

```swift
import CoreGraphics
import XCTest
@testable import ITextKit

final class ITextStyleTests: XCTestCase {
    func testStrokePreservesInputAndResolvesOutwardWidth() {
        let stroke = ITextStroke(paint: ITextPaint.solid("ink"), width: 2)
        XCTAssertEqual(stroke.width, 2)
        XCTAssertEqual(stroke._resolved?.outwardWidth, 2)
        XCTAssertEqual(stroke._resolved?.centeredLineWidth, 4)

        XCTAssertEqual(
            ITextStroke(paint: ITextPaint.solid("ink"), width: -1)._resolved?.outwardWidth,
            0
        )
        XCTAssertEqual(
            ITextStroke(paint: ITextPaint.solid("ink"), width: .infinity)._resolved?.outwardWidth,
            0
        )
        XCTAssertEqual(
            ITextStroke(paint: ITextPaint.solid("ink"), width: 100)._resolved?.outwardWidth,
            64
        )
    }

    func testColorsInitializerDistributesLocations() {
        let gradient = ITextLinearGradient(
            colors: ["a", "b", "c"],
            startPoint: .leading,
            endPoint: .trailing
        )
        XCTAssertEqual(gradient.stops.map(\.location), [0, 0.5, 1])
    }

    func testGradientNormalizationHandlesEmptyOneColorAndStableStops() {
        XCTAssertNil(ITextLinearGradient<String>(colors: [])._resolved(isRightToLeft: false))

        let one = ITextLinearGradient(colors: ["a"])
        XCTAssertEqual(one._resolved(isRightToLeft: false)?.colors, ["a"])

        let gradient = ITextLinearGradient(stops: [
            .init(color: "late", location: 2),
            .init(color: "firstHard", location: 0.5),
            .init(color: "secondHard", location: 0.5),
            .init(color: "nan", location: .nan)
        ])
        let resolved = gradient._resolved(isRightToLeft: false)
        XCTAssertEqual(resolved?.locations, [0.5, 0.5, 1, 1])
        XCTAssertEqual(resolved?.colors, ["firstHard", "secondHard", "late", "nan"])
    }

    func testSemanticPointsMirrorAndUnitPointsStayPhysical() {
        let ltr = ITextLinearGradient(colors: [0, 1])._resolved(isRightToLeft: false)
        let rtl = ITextLinearGradient(colors: [0, 1])._resolved(isRightToLeft: true)
        XCTAssertEqual(ltr?.startPoint, CGPoint(x: 0, y: 0.5))
        XCTAssertEqual(ltr?.endPoint, CGPoint(x: 1, y: 0.5))
        XCTAssertEqual(rtl?.startPoint, CGPoint(x: 1, y: 0.5))
        XCTAssertEqual(rtl?.endPoint, CGPoint(x: 0, y: 0.5))

        let physical = ITextLinearGradient(
            colors: [0, 1],
            startPoint: .unit(x: 0.2, y: 0.3),
            endPoint: .unit(x: 0.8, y: 0.7)
        )
        XCTAssertEqual(
            physical._resolved(isRightToLeft: true)?.startPoint,
            CGPoint(x: 0.2, y: 0.3)
        )
    }
}
```

- [ ] **Step 2: Run the focused test and verify it fails because the style types do not exist**

Run:

```bash
xcodebuild -quiet -scheme ITextKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ITextKitCoreTests/ITextStyleTests test
```

Expected: compile failure naming `ITextStroke`, `ITextLinearGradient`, or another missing style type.

- [ ] **Step 3: Implement the public values and internal normalization**

Use these exact public declarations and defaults:

```swift
public enum ITextGradientPoint: Hashable, Sendable {
    case topLeading
    case top
    case topTrailing
    case leading
    case center
    case trailing
    case bottomLeading
    case bottom
    case bottomTrailing
    case unit(x: CGFloat, y: CGFloat)
}

public struct ITextGradientStop<ColorValue> {
    public var color: ColorValue
    public var location: CGFloat

    public init(color: ColorValue, location: CGFloat) {
        self.color = color
        self.location = location
    }
}

public struct ITextLinearGradient<ColorValue> {
    public var stops: [ITextGradientStop<ColorValue>]
    public var startPoint: ITextGradientPoint
    public var endPoint: ITextGradientPoint

    public init(
        stops: [ITextGradientStop<ColorValue>],
        startPoint: ITextGradientPoint = .leading,
        endPoint: ITextGradientPoint = .trailing
    ) {
        self.stops = stops
        self.startPoint = startPoint
        self.endPoint = endPoint
    }

    public init(
        colors: [ColorValue],
        startPoint: ITextGradientPoint = .leading,
        endPoint: ITextGradientPoint = .trailing
    ) {
        let divisor = max(colors.count - 1, 1)
        self.stops = colors.enumerated().map {
            ITextGradientStop(color: $0.element, location: CGFloat($0.offset) / CGFloat(divisor))
        }
        self.startPoint = startPoint
        self.endPoint = endPoint
    }
}

public enum ITextPaint<ColorValue> {
    case solid(ColorValue)
    case linearGradient(ITextLinearGradient<ColorValue>)
}

public struct ITextStroke<ColorValue> {
    public var paint: ITextPaint<ColorValue>
    public var width: CGFloat

    public init(paint: ITextPaint<ColorValue>, width: CGFloat) {
        self.paint = paint
        self.width = width
    }
}

public struct ITextStyle<ColorValue> {
    public var fill: ITextPaint<ColorValue>?
    public var stroke: ITextStroke<ColorValue>?

    public init(
        fill: ITextPaint<ColorValue>? = nil,
        stroke: ITextStroke<ColorValue>? = nil
    ) {
        self.fill = fill
        self.stroke = stroke
    }
}

public typealias ITextUIKitStyle = ITextStyle<UIColor>
public typealias ITextSwiftUIStyle = ITextStyle<Color>
```

Add conditional `Equatable` conformances when `ColorValue: Equatable`. Resolve non-finite stop locations to their evenly distributed input index, clamp them to `0...1`, then sort by `(location, originalIndex)` so duplicate locations remain stable. Empty gradients resolve to `nil`; one-color gradients resolve to `.solid`. Equal resolved endpoints also resolve to the first solid color. Clamp semantic/unit points exactly as specified in the design.

- [ ] **Step 4: Run the focused test and the existing configuration tests**

Run:

```bash
xcodebuild -quiet -scheme ITextKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ITextKitCoreTests/ITextStyleTests -only-testing:ITextKitCoreTests/ITextConfigurationTests test
```

Expected: both suites pass.

- [ ] **Step 5: Commit the public style interface**

```bash
git add Sources/ITextKit/Core/ITextLinearGradient.swift Sources/ITextKit/Core/ITextStyle.swift Tests/ITextKitCoreTests/ITextStyleTests.swift
git commit -m "feat: add styled text values"
```

---

### Task 2: Bounded Glyph Cache and Immutable Layout Records

**Files:**

- Create: `Sources/ITextKit/Internal/StyledText/ITextAttributedContent.swift`
- Create: `Sources/ITextKit/Internal/StyledText/ITextGlyphPathCache.swift`
- Create: `Sources/ITextKit/Internal/StyledText/ITextLayoutResult.swift`
- Create: `Tests/ITextKitCoreTests/ITextGlyphPathCacheTests.swift`

**Interfaces:**

- Consumes: public style values from Task 1 and immutable `NSAttributedString` snapshots.
- Produces: `_ITextAttributedContent`, `_ITextGlyphPathKey`, `_ITextGlyphPathProviding`, `_ITextGlyphPathCache`, `_ITextLayoutRequest`, `_ITextLayoutResult`, `_ITextGlyphRecord`, `_ITextFallbackRun`, and `_ITextDecorationRecord`.
- Cache production limits: `countLimit = 2_048`, `totalCostLimit = 8 * 1_024 * 1_024`.

- [ ] **Step 1: Write failing cache tests with an injectable builder**

```swift
import CoreText
import XCTest
@testable import ITextKit

final class ITextGlyphPathCacheTests: XCTestCase {
    func testEqualFontGlyphAndTransformBuildOnce() {
        var buildCount = 0
        let cache = _ITextGlyphPathCache(countLimit: 8, totalCostLimit: 4_096)
        let font = CTFontCreateWithName("Helvetica" as CFString, 20, nil)

        let first = cache.path(font: font, glyph: 12, transform: .identity) {
            buildCount += 1
            return CGPath(rect: CGRect(x: 0, y: 0, width: 10, height: 10), transform: nil)
        }
        let second = cache.path(font: font, glyph: 12, transform: .identity) {
            buildCount += 1
            return nil
        }

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertEqual(buildCount, 1)
    }

    func testDifferentGlyphOrTransformUsesDifferentEntries() {
        var buildCount = 0
        let cache = _ITextGlyphPathCache(countLimit: 8, totalCostLimit: 4_096)
        let font = CTFontCreateWithName("Helvetica" as CFString, 20, nil)
        for glyph in [CGGlyph(1), CGGlyph(2)] {
            _ = cache.path(font: font, glyph: glyph, transform: .identity) {
                buildCount += 1
                return CGPath(rect: .init(x: 0, y: 0, width: 4, height: 4), transform: nil)
            }
        }
        _ = cache.path(font: font, glyph: 1, transform: .init(scaleX: 2, y: 2)) {
            buildCount += 1
            return CGPath(rect: .init(x: 0, y: 0, width: 8, height: 8), transform: nil)
        }
        XCTAssertEqual(buildCount, 3)
    }

    func testRemoveAllObjectsForMemoryPressureForcesRebuild() {
        var buildCount = 0
        let cache = _ITextGlyphPathCache(countLimit: 8, totalCostLimit: 4_096)
        let font = CTFontCreateWithName("Helvetica" as CFString, 20, nil)
        let build: () -> CGPath? = {
            buildCount += 1
            return CGPath(rect: .init(x: 0, y: 0, width: 4, height: 4), transform: nil)
        }
        _ = cache.path(font: font, glyph: 1, transform: .identity, build: build)
        cache.removeAllObjects()
        _ = cache.path(font: font, glyph: 1, transform: .identity, build: build)
        XCTAssertEqual(buildCount, 2)
    }
}
```

- [ ] **Step 2: Run the focused tests and verify the missing cache types fail compilation**

```bash
xcodebuild -quiet -scheme ITextKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ITextKitCoreTests/ITextGlyphPathCacheTests test
```

Expected: compile failure for `_ITextGlyphPathCache`.

- [ ] **Step 3: Implement the internal seam and immutable records**

Use this cache seam so the layout engine can receive a fake in tests:

```swift
protocol _ITextGlyphPathProviding: AnyObject {
    func path(
        font: CTFont,
        glyph: CGGlyph,
        transform: CGAffineTransform,
        build: () -> CGPath?
    ) -> CGPath?
}

final class _ITextGlyphPathCache: _ITextGlyphPathProviding {
    static let shared = _ITextGlyphPathCache(
        countLimit: 2_048,
        totalCostLimit: 8 * 1_024 * 1_024
    )

    init(countLimit: Int, totalCostLimit: Int)
    func path(
        font: CTFont,
        glyph: CGGlyph,
        transform: CGAffineTransform,
        build: () -> CGPath?
    ) -> CGPath?
    func removeAllObjects()
}
```

Key entries by the font's PostScript name, point size, symbolic traits, variation dictionary description, glyph identifier, and all six transform scalars. Cache both successful paths and known missing paths using a private boxed enum, so color glyphs do not repeatedly call `CTFontCreatePathForGlyph`. Estimate cost as `max(64, path.boundingBoxOfPath.width * path.boundingBoxOfPath.height / 4)` and clamp to `Int.max` safely. Register for `UIApplication.didReceiveMemoryWarningNotification` and call `removeAllObjects`; unregister in `deinit`. Keep the observer and cache implementation internal.

Define layout records with immutable `let` properties. `_ITextLayoutRequest` must contain `attributedText`, `defaultFont`, `defaultColor`, `constrainedSize`, `numberOfLines`, `lineBreakMode`, `alignment`, `baselineAdjustment`, `adjustsFontSizeToFitWidth`, `minimumScaleFactor`, `allowsTightening`, `layoutDirection`, `displayScale`, and `outwardStrokeWidth`. `_ITextLayoutResult` must contain `size`, `typographicBounds`, `inkBounds`, `firstBaseline`, `lastBaseline`, `glyphs`, `fallbackRuns`, `decorations`, `isTruncated`, `scaleFactor`, and `layoutGeneration`.

`_ITextAttributedContent` copies its `NSAttributedString`, applies default font/color only to missing ranges, and preserves the documented font, color, kern, ligature, baseline, paragraph, underline, strikethrough, and native stroke attributes without mutating the source.

- [ ] **Step 4: Run cache tests and verify bounded behavior**

```bash
xcodebuild -quiet -scheme ITextKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ITextKitCoreTests/ITextGlyphPathCacheTests test
```

Expected: all cache tests pass.

- [ ] **Step 5: Commit the internal records and cache seam**

```bash
git add Sources/ITextKit/Internal/StyledText/ITextAttributedContent.swift Sources/ITextKit/Internal/StyledText/ITextGlyphPathCache.swift Sources/ITextKit/Internal/StyledText/ITextLayoutResult.swift Tests/ITextKitCoreTests/ITextGlyphPathCacheTests.swift
git commit -m "feat: add styled text layout records"
```

---

### Task 3: CoreText Layout Engine

**Files:**

- Create: `Sources/ITextKit/Internal/StyledText/ITextLayoutEngine.swift`
- Create: `Tests/ITextKitCoreTests/ITextLayoutEngineTests.swift`
- Modify: `Sources/ITextKit/Internal/StyledText/ITextLayoutResult.swift`

**Interfaces:**

- Consumes: `_ITextLayoutRequest`, `_ITextAttributedContent`, and `_ITextGlyphPathProviding` from Task 2.
- Produces: `struct _ITextLayoutEngine { func layout(_ request: _ITextLayoutRequest) -> _ITextLayoutResult }`.
- Produces deterministic single-line/multiline layout with stable glyph paths, fallback runs, decorations, baselines, truncation, and stroke-expanded size.

- [ ] **Step 1: Write failing geometry and shaping tests**

Cover exact invariants instead of system-font pixel constants:

```swift
import CoreText
import UIKit
import XCTest
@testable import ITextKit

final class ITextLayoutEngineTests: XCTestCase {
    private let engine = _ITextLayoutEngine(pathProvider: _ITextGlyphPathCache(
        countLimit: 128,
        totalCostLimit: 512 * 1_024
    ))

    func testOutwardStrokeExpandsSizeWithoutMovingBaselineRelativeToText() {
        let plain = layout("Outline", width: 300, stroke: 0)
        let stroked = layout("Outline", width: 300, stroke: 2)
        XCTAssertEqual(stroked.size.width, plain.size.width + 4, accuracy: 0.5)
        XCTAssertEqual(stroked.size.height, plain.size.height + 4, accuracy: 0.5)
        XCTAssertEqual(stroked.firstBaseline, plain.firstBaseline + 2, accuracy: 0.5)
    }

    func testConstrainedWidthReservesStrokeAndCanWrapEarlier() {
        let plain = layout("A wrapping sentence", width: 120, stroke: 0)
        let stroked = layout("A wrapping sentence", width: 120, stroke: 3)
        XCTAssertLessThanOrEqual(stroked.size.width, 120)
        XCTAssertGreaterThanOrEqual(stroked.size.height, plain.size.height)
    }

    func testEmptyTextHasZeroSizeAndNoRecords() {
        let result = layout("", width: 120, stroke: 3)
        XCTAssertEqual(result.size, .zero)
        XCTAssertTrue(result.glyphs.isEmpty)
        XCTAssertTrue(result.fallbackRuns.isEmpty)
    }

    func testCombiningArabicAndLigatureInputProducesFinitePlacedRecords() {
        let result = layout("A\u{0301} العربية office", width: 180, stroke: 1)
        XCTAssertGreaterThan(result.glyphs.count + result.fallbackRuns.count, 0)
        XCTAssertTrue(result.size.width.isFinite)
        XCTAssertTrue(result.size.height.isFinite)
        XCTAssertFalse(result.inkBounds.isNull)
    }

    func testColorEmojiUsesFallbackRecord() {
        let result = layout("👨‍👩‍👧‍👦", width: 180, stroke: 2)
        XCTAssertFalse(result.fallbackRuns.isEmpty)
    }

    private func layout(_ text: String, width: CGFloat, stroke: CGFloat) -> _ITextLayoutResult {
        engine.layout(_ITextLayoutRequest(
            attributedText: NSAttributedString(string: text),
            defaultFont: .systemFont(ofSize: 24),
            defaultColor: .label,
            constrainedSize: CGSize(width: width, height: .greatestFiniteMagnitude),
            numberOfLines: 0,
            lineBreakMode: .byWordWrapping,
            alignment: .natural,
            baselineAdjustment: .alignBaselines,
            adjustsFontSizeToFitWidth: false,
            minimumScaleFactor: 0,
            allowsTightening: false,
            layoutDirection: .leftToRight,
            displayScale: 3,
            outwardStrokeWidth: stroke
        ))
    }
}
```

Add separate tests for `numberOfLines = 1`, `.byTruncatingHead/.middle/.tail`, centered/right/natural alignment under both layout directions, preferred-width multiline layout, `minimumScaleFactor`, underline/strikethrough records, mixed fonts, and repeated equal requests producing identical geometry.

- [ ] **Step 2: Run the layout suite and verify it fails for the missing engine**

```bash
xcodebuild -quiet -scheme ITextKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ITextKitCoreTests/ITextLayoutEngineTests test
```

Expected: compile failure naming `_ITextLayoutEngine`.

- [ ] **Step 3: Implement CoreText line construction and truncation**

Implement `_ITextLayoutEngine.init(pathProvider:)` and `layout(_:)`. Use `CTTypesetterSuggestLineBreak` for word/character wrapping and `CTLineCreateTruncatedLine` for the final allowed line. Do not use an unbounded frame height as a cache key. Resolve natural alignment from paragraph style and requested layout direction. Apply RTL line origins without reversing the string.

For `adjustsFontSizeToFitWidth`, measure the single-line result at scale 1; when it exceeds the available glyph width, apply `max(minimumScaleFactor, availableWidth / naturalWidth)` to font sizes and kern/baseline metrics, then re-layout once. `allowsTightening` may reduce kern only after scaling and must never go below zero advance.

- [ ] **Step 4: Extract glyphs, native fallbacks, decorations, and baselines**

For every `CTRun`, read the run font, glyph IDs, positions, string indices, and status. Classify a run as fallback when its font has `.traitColorGlyphs` or every nonzero glyph lacks a path. For outline runs, obtain cached glyph paths, apply run text matrix and placed origin, and union their ink bounds. Retain the `CTLine` and run range in `_ITextFallbackRun` so the drawing plan can call `CTRunDraw` at the same origin.

Build underline and strikethrough records from effective run attributes, font metrics, run advance, and explicit decoration color. Round only final device-facing bounds to the supplied display scale; retain unrounded glyph positions.

Expand the returned outer size by `2 * outwardStrokeWidth`. When width is constrained, subtract that amount before line layout and cap the final width at the original finite constraint. Add the top stroke inset to both baselines.

- [ ] **Step 5: Run layout and cache suites**

```bash
xcodebuild -quiet -scheme ITextKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ITextKitCoreTests/ITextLayoutEngineTests -only-testing:ITextKitCoreTests/ITextGlyphPathCacheTests test
```

Expected: all tests pass, including color Emoji fallback and truncation variants.

- [ ] **Step 6: Commit the deterministic layout engine**

```bash
git add Sources/ITextKit/Internal/StyledText/ITextLayoutEngine.swift Sources/ITextKit/Internal/StyledText/ITextLayoutResult.swift Tests/ITextKitCoreTests/ITextLayoutEngineTests.swift
git commit -m "feat: lay out styled text with CoreText"
```

---

### Task 4: Direct Vector Drawing and UIKit Styled Label

**Files:**

- Create: `Sources/ITextKit/Internal/StyledText/ITextDrawingPlan.swift`
- Create: `Sources/ITextKit/Internal/StyledText/ITextDrawingLayer.swift`
- Create: `Sources/ITextKit/UIKit/ITextStyledLabel.swift`
- Create: `Tests/ITextKitUIKitTests/ITextDrawingPlanTests.swift`
- Create: `Tests/ITextKitUIKitTests/ITextStyledLabelTests.swift`

**Interfaces:**

- Consumes: `ITextUIKitStyle`, `_ITextLayoutEngine`, and `_ITextLayoutResult`.
- Produces: `_ITextResolvedCGStyle`, `_ITextDrawingPlan.draw(in:)`, `_ITextDrawingLayer.plan`, public `ITextStyledLabel.textStyle: ITextUIKitStyle?`, and internal `ITextStyledLabel._gradientReferenceAttributedText` for stable typewriter gradient coordinates.
- `ITextStyledLabel` is `public class`, not `final`, so `ITextShimmerLabel` can subclass it inside the module.

- [ ] **Step 1: Write failing drawing-plan pixel tests**

Render only in tests with `UIGraphicsImageRenderer`; production rendering remains direct vector drawing:

```swift
@MainActor
func render(_ label: UIView, size: CGSize, scale: CGFloat = 3) -> UIImage {
    label.frame = CGRect(origin: .zero, size: size)
    label.layoutIfNeeded()
    return UIGraphicsImageRenderer(size: size, format: {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return format
    }()).image { context in
        label.layer.render(in: context.cgContext)
    }
}
```

Test solid fill, horizontal gradient fill, solid stroke, gradient stroke, fill plus stroke, continuous two-line gradient, explicit decoration color, color Emoji fallback, and RTL semantic direction. Assert foreground pixel bounds and representative left/middle/right RGB values; do not compare the entire image to a brittle golden.

- [ ] **Step 2: Write failing UILabel-compatibility tests**

```swift
@MainActor
final class ITextStyledLabelTests: XCTestCase {
    func testNilStyleMatchesNativeIntrinsicSize() {
        let native = UILabel()
        native.text = "Native path"
        native.font = .systemFont(ofSize: 24, weight: .bold)

        let styled = ITextStyledLabel()
        styled.text = native.text
        styled.font = native.font
        styled.textStyle = nil

        XCTAssertEqual(styled.intrinsicContentSize, native.intrinsicContentSize)
    }

    func testTwoPointStrokeAddsFourPointsToUnconstrainedSize() {
        let label = ITextStyledLabel()
        label.text = "Outline"
        label.font = .systemFont(ofSize: 24)
        let base = label.intrinsicContentSize
        label.textStyle = .init(stroke: .init(paint: .solid(.black), width: 2))
        XCTAssertEqual(label.intrinsicContentSize.width, base.width + 4, accuracy: 1)
        XCTAssertEqual(label.intrinsicContentSize.height, base.height + 4, accuracy: 1)
    }

    func testMutableAttributedInputIsNotMutated() {
        let source = NSMutableAttributedString(
            string: "Rich",
            attributes: [.foregroundColor: UIColor.red]
        )
        let label = ITextStyledLabel()
        label.attributedText = source
        label.textStyle = .init(fill: .solid(.blue))
        XCTAssertEqual(source.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .red)
    }
}
```

Also test multiline `preferredMaxLayoutWidth`, `sizeThatFits`, `numberOfLines`, all truncation modes, first/last baseline offsets, Dynamic Type trait changes, `adjustsFontSizeToFitWidth`, `minimumScaleFactor`, shadow properties, style mutation invalidation, and empty text.

- [ ] **Step 3: Run both new UIKit suites and verify missing types fail**

```bash
xcodebuild -quiet -scheme ITextKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ITextKitUIKitTests/ITextDrawingPlanTests -only-testing:ITextKitUIKitTests/ITextStyledLabelTests test
```

Expected: compile failure for `ITextStyledLabel` or `_ITextDrawingPlan`.

- [ ] **Step 4: Implement platform color resolution and drawing order**

Resolve `UIColor` through the current `UITraitCollection`, multiply existing alpha rather than replacing it, and create device-RGB `CGGradient` values. Draw in this order: styled/native stroke, fill, decorations, then fallback runs. For a public stroke width `w`, call `context.setLineWidth(2 * w)`, `.round` line joins/caps, draw the path with `.stroke`, and draw fill above it. Clip gradient paint once to the combined target path and draw it across `layoutResult.inkBounds.insetBy(dx: -w, dy: -w)`.

`_ITextDrawingPlan` owns no view, animation, cache, or global state. Its initializer accepts `gradientBounds` separately from the visible layout bounds; normal labels pass their visible ink bounds, while typewriter passes the full-text reference ink bounds. `_ITextDrawingLayer` stores one immutable plan, sets `contentsScale`, redraws only when the plan or traits change, and disables implicit animations for plan/bounds/position updates.

- [ ] **Step 5: Implement `ITextStyledLabel` native and styled paths**

Add this public surface:

```swift
@MainActor
public class ITextStyledLabel: UILabel {
    public var textStyle: ITextUIKitStyle? {
        didSet {
            invalidateStyledLayoutIfNeeded(oldValue: oldValue)
        }
    }
}
```

When `textStyle == nil`, remove/hide the private drawing layer and delegate drawing, `textRect`, intrinsic sizing, `sizeThatFits`, and baselines to `super`. When styled, copy attributed input, form a layout request from current UILabel properties, reserve stroke insets, install the drawing plan, suppress native glyph drawing, and report the shared result. Override every property that affects layout or paint and perform the narrow invalidation defined by the spec. Reassigning equal resolved content/style must be idempotent.

Preserve the label as the sole accessibility and interaction owner. Add internal `var _gradientReferenceAttributedText: NSAttributedString?`; when non-`nil`, lay it out with the same font, width, line, and trait inputs only to obtain the drawing plan's `gradientBounds`. It must not change the visible label size, baseline, accessibility value, or glyph records. Apply `shadowColor`/`shadowOffset` to the drawing context rather than duplicating content. On `traitCollectionDidChange`, rebuild layout only for content-size-category changes; rebuild paint only for color appearance changes.

- [ ] **Step 6: Run layout, drawing, and label suites**

```bash
xcodebuild -quiet -scheme ITextKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ITextKitCoreTests/ITextLayoutEngineTests -only-testing:ITextKitUIKitTests/ITextDrawingPlanTests -only-testing:ITextKitUIKitTests/ITextStyledLabelTests test
```

Expected: all suites pass and mutation tests show paint-only changes do not increment `layoutGeneration`.

- [ ] **Step 7: Commit the renderer and UIKit Adapter**

```bash
git add Sources/ITextKit/Internal/StyledText/ITextDrawingPlan.swift Sources/ITextKit/Internal/StyledText/ITextDrawingLayer.swift Sources/ITextKit/UIKit/ITextStyledLabel.swift Tests/ITextKitUIKitTests/ITextDrawingPlanTests.swift Tests/ITextKitUIKitTests/ITextStyledLabelTests.swift
git commit -m "feat: render styled UILabel text"
```

---

### Task 5: UIKit Motion and Shimmer Integration

**Files:**

- Modify: `Sources/ITextKit/UIKit/ITextRotatorView.swift`
- Modify: `Sources/ITextKit/UIKit/ITextMarqueeView.swift`
- Modify: `Sources/ITextKit/UIKit/ITextTypewriterView.swift`
- Modify: `Sources/ITextKit/UIKit/ITextShimmerLabel.swift`
- Modify: `Tests/ITextKitUIKitTests/ITextKitUIKitAPITests.swift`
- Modify: `Tests/ITextKitUIKitTests/ITextShimmerLabelTests.swift`

**Interfaces:**

- Consumes: `ITextStyledLabel` and `ITextUIKitStyle` from Task 4.
- Produces: `textStyle: ITextUIKitStyle?` on all four UIKit controls.
- Preserves all existing initializers and playback methods.

- [ ] **Step 1: Add failing interface and composition tests**

Add tests that assign one shared style to rotator, marquee, typewriter, and shimmer, then assert every private visual label is an `ITextStyledLabel` with an equal style. Verify:

```swift
let style = ITextUIKitStyle(
    fill: .linearGradient(.init(colors: [.red, .blue])),
    stroke: .init(paint: .linearGradient(.init(colors: [.white, .black])), width: 2)
)

let marquee = ITextMarqueeView(text: "A long styled marquee", playbackState: .paused)
marquee.textStyle = style
XCTAssertEqual(marquee.textStyle, style)
XCTAssertTrue(marquee.subviews.allSatisfy { $0 is ITextStyledLabel })
```

Add mutation assertions:

- Rotator style change keeps current/next index, transition progress, and explicit playback state while invalidating height.
- Marquee stroke-width/font change returns to semantic leading and preserves explicit playback state; paint-only color change preserves offset.
- Typewriter style change preserves revealed Character count; width/font changes remeasure the current prefix and the full-text gradient reference, while animation frames between Character boundaries do neither.
- Shimmer remains a `UILabel`, exposes one accessibility element, installs one keyed animation, and highlights both fill and stroke.

- [ ] **Step 2: Run the existing and new UIKit interface tests and verify failure**

```bash
xcodebuild -quiet -scheme ITextKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ITextKitUIKitTests/ITextKitUIKitAPITests -only-testing:ITextKitUIKitTests/ITextShimmerLabelTests test
```

Expected: compile failure because the motion controls have no `textStyle`.

- [ ] **Step 3: Replace private labels and propagate style**

Change only the private label types:

```swift
private let primaryLabel = ITextStyledLabel()
private let repeatedLabel = ITextStyledLabel()
private let currentLabel = ITextStyledLabel()
private let nextLabel = ITextStyledLabel()
private let label = ITextStyledLabel()
```

Add to each public control:

```swift
public var textStyle: ITextUIKitStyle? {
    didSet {
        guard textStyle != oldValue else { return }
        synchronizeLabelStyleForTextStyleChange(oldValue: oldValue)
    }
}
```

Separate layout-affecting changes (`stroke.width`) from paint-only changes. Reuse existing font/content restart behavior only for layout-affecting marquee changes. Do not reset explicit playback state.

For `ITextTypewriterView`, assign the immutable full input to `label._gradientReferenceAttributedText` whenever styled rendering is active and assign only the revealed prefix to `label.attributedText`. This gives the drawing plan stable final gradient bounds while the public intrinsic size continues to follow the visible prefix.

- [ ] **Step 4: Make shimmer subclass and mirror styled rendering**

Change the declaration and overlay type:

```swift
public final class ITextShimmerLabel: ITextStyledLabel {
    private let shimmerOverlayLabel: ITextStyledLabel
}
```

Mirror `textStyle` to the overlay, replacing every solid/gradient paint color with the resolved `highlightColor` while preserving stroke width. The base label stays the only layout/accessibility owner. Continue to animate exactly one `CAGradientLayer` mask under key `ITextKit.shimmer.position`; do not introduce a timer or display link.

- [ ] **Step 5: Run all UIKit tests**

```bash
xcodebuild -quiet -scheme ITextKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ITextKitUIKitTests test
```

Expected: existing and new UIKit suites pass, including scene lifecycle and RTL inheritance.

- [ ] **Step 6: Commit UIKit composition**

```bash
git add Sources/ITextKit/UIKit/ITextRotatorView.swift Sources/ITextKit/UIKit/ITextMarqueeView.swift Sources/ITextKit/UIKit/ITextTypewriterView.swift Sources/ITextKit/UIKit/ITextShimmerLabel.swift Tests/ITextKitUIKitTests/ITextKitUIKitAPITests.swift Tests/ITextKitUIKitTests/ITextShimmerLabelTests.swift
git commit -m "feat: style UIKit text effects"
```

---

### Task 6: SwiftUI Styled Text Adapter

**Files:**

- Create: `Sources/ITextKit/SwiftUI/ITextStyledText.swift`
- Create: `Tests/ITextKitSwiftUITests/ITextStyledTextTests.swift`
- Modify: `Tests/ITextKitSwiftUITests/ITextKitSwiftUIAPITests.swift`

**Interfaces:**

- Consumes: `ITextStyledLabel`, `ITextSwiftUIStyle`, SwiftUI layout/environment values, `String`, `NSAttributedString`, and `UIFont`.
- Produces: public `ITextStyledText` with plain and rich initializers exactly matching the approved design.
- Produces privately: `_ITextStyledLabelRepresentable: UIViewRepresentable` and an internal styled-text initializer with `gradientReferenceAttributedText`.

- [ ] **Step 1: Write failing compile and hosted-layout tests**

```swift
import SwiftUI
import UIKit
import XCTest
@testable import ITextKit

@MainActor
final class ITextStyledTextTests: XCTestCase {
    func testPlainAndRichInterfacesConstruct() {
        let style = ITextSwiftUIStyle(
            fill: .linearGradient(.init(colors: [.red, .blue])),
            stroke: .init(paint: .solid(.white), width: 2)
        )
        _ = ITextStyledText("Plain", font: .systemFont(ofSize: 24), style: style)
        _ = ITextStyledText(
            attributedText: NSAttributedString(
                string: "Rich",
                attributes: [.font: UIFont.systemFont(ofSize: 24, weight: .bold)]
            ),
            style: style
        )
    }

    func testConstrainedWidthWrapsAndReportsGreaterHeight() {
        let view = ITextStyledText(
            "A styled sentence that must wrap across lines",
            font: .systemFont(ofSize: 24),
            style: .init(stroke: .init(paint: .solid(.black), width: 2))
        )
        let wide = UIHostingController(rootView: view.frame(width: 300))
        let narrow = UIHostingController(rootView: view.frame(width: 120))
        XCTAssertGreaterThan(
            narrow.sizeThatFits(in: CGSize(width: 120, height: 500)).height,
            wide.sizeThatFits(in: CGSize(width: 300, height: 500)).height
        )
    }
}
```

Add tests for ideal unconstrained size, `lineLimit`, multiline alignment, LTR/RTL environment, Dynamic Type scaling of the default font, explicit attributed fonts remaining caller-owned, accessibility label, and an outer `.font(.largeTitle)` not changing the styled intrinsic size.

- [ ] **Step 2: Run the SwiftUI Adapter tests and verify missing interface failure**

```bash
xcodebuild -quiet -scheme ITextKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ITextKitSwiftUITests/ITextStyledTextTests test
```

Expected: compile failure for `ITextStyledText`.

- [ ] **Step 3: Implement the public SwiftUI view**

Use these exact initializers:

```swift
@MainActor
public struct ITextStyledText: View {
    public init(
        _ text: String,
        font: UIFont = .preferredFont(forTextStyle: .body),
        style: ITextSwiftUIStyle,
        adjustsFontForContentSizeCategory: Bool = true
    )

    public init(
        attributedText: NSAttributedString,
        defaultFont: UIFont = .preferredFont(forTextStyle: .body),
        style: ITextSwiftUIStyle,
        adjustsFontForContentSizeCategory: Bool = true
    )
}
```

Store an immutable attributed snapshot. Resolve SwiftUI `Color` with `UIColor(color)` in the current environment/traits, then assign the resulting `ITextUIKitStyle` to the underlying label. Map `.lineLimit`, `.multilineTextAlignment`, `.layoutDirection`, `.dynamicTypeSize`, `.displayScale`, and accessibility values. Do not inspect or depend on `EnvironmentValues.font`.

Add an internal initializer that accepts `gradientReferenceAttributedText: NSAttributedString?` and forwards it to the label's internal property. Public initializers always pass `nil`; only styled typewriter passes the immutable full text.

For iOS 16+, implement the representable `sizeThatFits(_:uiView:context:)` witness using the proposed width and `label.sizeThatFits`. For iOS 15, preserve the same result through `ITextStyledLabel` intrinsic size plus `preferredMaxLayoutWidth` updates when its actual bounds width changes. Guard equality so the feedback pass terminates rather than invalidating indefinitely.

- [ ] **Step 4: Run SwiftUI Adapter and UIKit label suites**

```bash
xcodebuild -quiet -scheme ITextKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ITextKitSwiftUITests/ITextStyledTextTests -only-testing:ITextKitUIKitTests/ITextStyledLabelTests test
```

Expected: both suites pass and hosted constrained layout stabilizes without repeated layout generation.

- [ ] **Step 5: Commit the SwiftUI Adapter**

```bash
git add Sources/ITextKit/SwiftUI/ITextStyledText.swift Tests/ITextKitSwiftUITests/ITextStyledTextTests.swift Tests/ITextKitSwiftUITests/ITextKitSwiftUIAPITests.swift
git commit -m "feat: add SwiftUI styled text"
```

---

### Task 7: SwiftUI Rotator, Marquee, and Typewriter Integration

**Files:**

- Create: `Sources/ITextKit/SwiftUI/ITextSwiftUIContent.swift`
- Modify: `Sources/ITextKit/SwiftUI/ITextRotator.swift`
- Modify: `Sources/ITextKit/SwiftUI/ITextMarquee.swift`
- Modify: `Sources/ITextKit/SwiftUI/ITextTypewriter.swift`
- Modify: `Tests/ITextKitSwiftUITests/ITextKitSwiftUIAPITests.swift`
- Modify: `Tests/ITextKitSwiftUITests/ITextStyledTextTests.swift`

**Interfaces:**

- Consumes: native `AttributedString`, styled `NSAttributedString`, `UIFont`, `ITextSwiftUIStyle`, and `ITextStyledText`.
- Produces internally: `_ITextSwiftUIContent`, which preserves native and styled content without lossy conversion.
- Produces public styled overloads on `ITextRotator`, `ITextMarquee`, and `ITextTypewriter`.

- [ ] **Step 1: Write failing interface tests for every styled overload**

Use these calls so overload labels remain unambiguous:

```swift
let style = ITextSwiftUIStyle(
    fill: .linearGradient(.init(colors: [.pink, .orange])),
    stroke: .init(paint: .solid(.black), width: 1.5)
)

_ = ITextRotator(
    texts: ["First", "Second"],
    textStyle: style,
    playbackState: .paused
)
_ = ITextRotator(
    styledAttributedTexts: [NSAttributedString(string: "Rich")],
    textStyle: style,
    playbackState: .paused
)
_ = ITextMarquee(
    text: "Styled marquee",
    textStyle: style,
    playbackState: .paused
)
_ = ITextMarquee(
    styledAttributedText: NSAttributedString(string: "Rich marquee"),
    textStyle: style,
    playbackState: .paused
)
_ = ITextTypewriter(text: "Styled typing", textStyle: style)
_ = ITextTypewriter(
    styledAttributedText: NSAttributedString(string: "Rich typing"),
    textStyle: style
)
```

Add hosted tests for rotator variable height including stroke, marquee repeated-copy measurement/RTL, and typewriter stable full-text gradient geometry while the visible prefix size grows. Assert one accessibility element and plain full text.

- [ ] **Step 2: Run the SwiftUI interface suite and verify overload failure**

```bash
xcodebuild -quiet -scheme ITextKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ITextKitSwiftUITests/ITextKitSwiftUIAPITests -only-testing:ITextKitSwiftUITests/ITextStyledTextTests test
```

Expected: compile failure for the required `textStyle`/`styledAttributedText` labels.

- [ ] **Step 3: Add the native/styled content enum**

Define:

```swift
enum _ITextSwiftUIContent: Equatable {
    case native(AttributedString)
    case styled(NSAttributedString, defaultFont: UIFont)

    var plainText: String
    var characterCount: Int
    func prefix(throughCharacter count: Int) -> _ITextSwiftUIContent
}
```

Implement equality for `NSAttributedString` with `isEqual(to:)` and for `UIFont` with `isEqual`. Build prefixes at complete Swift `Character` boundaries using `NSString` ranges so family Emoji and combining sequences never split. Do not convert native `AttributedString` into `NSAttributedString`.

- [ ] **Step 4: Add exact styled overloads and branch rendering**

For each control, keep existing initializers byte-for-byte source compatible and add plain/rich styled overloads with `textStyle` required and these defaults: `font/defaultFont = .preferredFont(forTextStyle: .body)` and `adjustsFontForContentSizeCategory = true`. Preserve configuration and playback parameter defaults.

Use one internal render function:

```swift
@ViewBuilder
private func renderedText(_ content: _ITextSwiftUIContent) -> some View {
    switch content {
    case .native(let value):
        Text(value)
    case .styled(let value, let defaultFont):
        ITextStyledText(
            attributedText: value,
            defaultFont: defaultFont,
            style: styledTextStyle,
            adjustsFontForContentSizeCategory: adjustsStyledFont
        )
    }
}
```

Keep motion state engines framework-independent. Rotator applies offsets/opacity after styled rendering. Marquee measures and repeats styled content through the same preference flow. Typewriter passes its immutable full attributed content as `gradientReferenceAttributedText` and its current Character-safe prefix as visible content; the reference supplies stable gradient bounds, the prefix supplies ideal size, and only revealed-Character changes may invalidate either visible layout or reference selection.

- [ ] **Step 5: Run all SwiftUI tests**

```bash
xcodebuild -quiet -scheme ITextKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ITextKitSwiftUITests test
```

Expected: existing native `Text` tests and all styled overload/layout tests pass.

- [ ] **Step 6: Commit SwiftUI motion composition**

```bash
git add Sources/ITextKit/SwiftUI/ITextSwiftUIContent.swift Sources/ITextKit/SwiftUI/ITextRotator.swift Sources/ITextKit/SwiftUI/ITextMarquee.swift Sources/ITextKit/SwiftUI/ITextTypewriter.swift Tests/ITextKitSwiftUITests/ITextKitSwiftUIAPITests.swift Tests/ITextKitSwiftUITests/ITextStyledTextTests.swift
git commit -m "feat: style SwiftUI text effects"
```

---

### Task 8: SwiftUI Shimmer Alpha-Mask Composition

**Files:**

- Modify: `Sources/ITextKit/SwiftUI/ITextShimmerModifier.swift`
- Modify: `Tests/ITextKitSwiftUITests/ITextShimmerModifierTests.swift`
- Modify: `Tests/ITextKitSwiftUITests/ITextStyledTextTests.swift`
- Create: `Tests/ITextKitUIKitTests/ITextStyledTextVisualTests.swift`

**Interfaces:**

- Consumes: any supported rendered text content, including `ITextStyledText`.
- Produces: unchanged public `.shimmerText(...)` interface with a highlight that follows the final alpha of fill and stroke.
- Preserves: original content as sole layout, hit-testing, and accessibility owner; one native animation and no timing callback.

- [ ] **Step 1: Add a failing visual mutation test for styled shimmer**

Host an `ITextStyledText` with a 3-point stroke, render inactive and active shimmer states at a deterministic mask position, and assert changed highlight pixels exist both inside the fill and in the outward-only stroke band. Also assert the rendered bounds and accessibility label do not change between states.

Add a source-level construction test:

```swift
let styled = ITextStyledText(
    "Working…",
    font: .systemFont(ofSize: 28, weight: .bold),
    style: .init(
        fill: .linearGradient(.init(colors: [.blue, .purple])),
        stroke: .init(paint: .solid(.black), width: 2)
    )
)
.shimmerText(highlight: .white)
_ = styled
```

- [ ] **Step 2: Run shimmer and visual suites and verify the stroke-band assertion fails**

```bash
xcodebuild -quiet -scheme ITextKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ITextKitSwiftUITests/ITextShimmerModifierTests -only-testing:ITextKitUIKitTests/ITextStyledTextVisualTests test
```

Expected: construction succeeds after Task 6, but current foreground-style recoloring does not highlight platform-backed stroke pixels.

- [ ] **Step 3: Replace foreground recoloring with rendered-alpha masking**

Build the overlay in this order:

```swift
Rectangle()
    .fill(highlight.opacity(Double(configuration.intensity)))
    .mask { content }
    .mask { movingBandMask }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
```

Keep the original `content` outside the overlay as the only layout owner. Preserve the current configuration identity, semantic direction, Reduce Motion removal, and native repeating animation. Do not add Canvas, `TimelineView`, a display link, or a package timer.

- [ ] **Step 4: Run all shimmer and styled visual tests**

```bash
xcodebuild -quiet -scheme ITextKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ITextKitSwiftUITests/ITextShimmerModifierTests -only-testing:ITextKitSwiftUITests/ITextStyledTextTests -only-testing:ITextKitUIKitTests/ITextShimmerLabelTests -only-testing:ITextKitUIKitTests/ITextStyledTextVisualTests test
```

Expected: all tests pass and styled shimmer affects fill plus outward stroke without changing geometry.

- [ ] **Step 5: Commit shimmer composition**

```bash
git add Sources/ITextKit/SwiftUI/ITextShimmerModifier.swift Tests/ITextKitSwiftUITests/ITextShimmerModifierTests.swift Tests/ITextKitSwiftUITests/ITextStyledTextTests.swift Tests/ITextKitUIKitTests/ITextStyledTextVisualTests.swift
git commit -m "fix: shimmer complete styled text"
```

---

### Task 9: Visual Regression and Performance Gates

**Files:**

- Modify: `Tests/ITextKitUIKitTests/ITextStyledTextVisualTests.swift`
- Create: `Tests/ITextKitUIKitTests/ITextStyledTextPerformanceTests.swift`
- Create after physical measurements: `docs/performance/0.3.0-styled-text.md`

**Interfaces:**

- Consumes: production UIKit/SwiftUI Adapters and internal `layoutGeneration`/cache statistics through `@testable import`.
- Produces: repeatable visual assertions, XCTest metrics, Instruments procedure, and recorded physical-device evidence.
- Does not add a public production test seam.

- [ ] **Step 1: Complete the visual matrix**

Add parameterized fixtures for 0, 0.5, 1, 2, and 3-point strokes and assert the foreground bounds expand by twice the public width within one physical pixel. Cover:

```swift
let widths: [CGFloat] = [0, 0.5, 1, 2, 3]
let samples = [
    "Outline",
    "渐变描边",
    "العربية",
    "A\u{0301}",
    "office",
    "👨‍👩‍👧‍👦"
]
```

Test solid/gradient fill, solid/gradient stroke, combined gradients, multiline continuity, semantic RTL mirroring, physical-unit stability, color Emoji fallback, and mutations of paint, width, font, bounds, and traits. Render existing production views; test-only image creation is permitted.

- [ ] **Step 2: Add measurable cold, warm, animation, and cache tests**

Use `XCTClockMetric`, `XCTCPUMetric`, and `XCTMemoryMetric` with optimized test execution. The cold test creates a fresh engine/cache and lays out the same 100-glyph multiline gradient-fill/gradient-stroke fixture 100 times. The warm test reuses one Adapter and equal inputs. The animation test hosts ten styled marquee/shimmer instances for ten seconds and asserts `layoutGeneration` and glyph-path build counts do not change after startup. The cache test asserts entry count never exceeds 2,048 and estimated cost never exceeds 8 MiB.

The test names must be:

```swift
func testColdHundredGlyphLayoutPerformance()
func testWarmUnchangedRedrawPerformance()
func testTenAnimationsDoNotRebuildLayoutOrPaths()
func testGlyphCacheStaysWithinConfiguredLimits()
func testTwentyRowScrollComparedWithNativeBaseline()
```

- [ ] **Step 3: Run the full visual suite in Release configuration**

```bash
xcodebuild -quiet -scheme ITextKit -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ITextKitUIKitTests/ITextStyledTextVisualTests test
```

Expected: all pixel, geometry, RTL, multiline, Emoji, and mutation assertions pass.

- [ ] **Step 4: Run physical-device performance tests and Instruments**

Connect a physical iPhone 12 or an older supported iPhone, select its destination in Xcode, and run `ITextStyledTextPerformanceTests` in Release configuration after one warm-up run. Repeat at least three measured runs. Profile the 20-row fixture with Time Profiler and Core Animation.

Required results:

- Cold 100-glyph layout-and-plan p95 is at most 4 ms over at least 100 iterations.
- Warm unchanged redraw p95 is at most 1 ms.
- Ten simultaneous marquee/shimmer instances rebuild layout/path zero times after startup over 10 seconds.
- Styled 20-row p95 frame time exceeds the native UILabel fixture by at most 1 ms.
- No ITextKit layout/path interval blocks the main thread for more than 16.67 ms.
- Cache stays within 2,048 entries and estimated 8 MiB cost.

If the required physical device is unavailable or any result fails, stop before release. Do not weaken the limits in code or documentation.

- [ ] **Step 5: Record measured evidence without estimates**

Create `docs/performance/0.3.0-styled-text.md` containing the exact commit SHA, device model, OS version, build configuration, warm-up count, run count, input fixture, raw XCTest summaries, calculated p95 values, Instruments trace filename, layout/path rebuild counts, cache peak count/cost, and pass/fail conclusion for each gate. Copy measured numbers; do not enter projected values.

- [ ] **Step 6: Commit tests and passing performance evidence**

```bash
git add Tests/ITextKitUIKitTests/ITextStyledTextVisualTests.swift Tests/ITextKitUIKitTests/ITextStyledTextPerformanceTests.swift docs/performance/0.3.0-styled-text.md
git commit -m "test: verify styled text rendering performance"
```

---

### Task 10: Documentation, Full Validation, and 0.3.0 Release

**Files:**

- Modify: `README.md`
- Modify: `ROADMAP.md`
- Modify: `Sources/ITextKit/Documentation.docc/ITextKit.md`
- Modify: `Sources/ITextKit/Documentation.docc/AttributedText.md`
- Modify: `Sources/ITextKit/Documentation.docc/TextShimmer.md`
- Create: `Sources/ITextKit/Documentation.docc/StyledText.md`
- Verify: `docs/performance/0.3.0-styled-text.md`

**Interfaces:**

- Consumes: all shipped interfaces and measured performance evidence.
- Produces: complete usage, limitations, ordering, accessibility, performance, and migration documentation plus annotated tag `0.3.0`.

- [ ] **Step 1: Update README and DocC with compilable examples**

Document both frameworks using real interfaces:

```swift
let label = ITextStyledLabel()
label.text = "Fantasia"
label.font = .systemFont(ofSize: 28, weight: .bold)
label.textStyle = .init(
    fill: .linearGradient(.init(colors: [.systemPink, .systemOrange])),
    stroke: .init(
        paint: .linearGradient(.init(colors: [.white, .systemYellow])),
        width: 2
    )
)
```

```swift
ITextStyledText(
    "Fantasia",
    font: .systemFont(ofSize: 28, weight: .bold),
    style: .init(
        fill: .linearGradient(.init(colors: [.pink, .orange])),
        stroke: .init(
            paint: .linearGradient(.init(colors: [.white, .yellow])),
            width: 2
        )
    )
)
.shimmerText()
```

State plainly that the SwiftUI styled path accepts `String`/`NSAttributedString + UIFont`, outer `.font(...)` does not alter it, and arbitrary `Text` cannot be transparently outlined. Document real-point semantics, `0...64` resolution, empty/one-color gradients, RTL/unit points, multiline continuity, color Emoji fallback, stroke sizing, modifier ordering, Dynamic Type ownership, and effect composition.

- [ ] **Step 2: Update release metadata and Roadmap**

Change README badges/dependency examples from `0.2.2` to `0.3.0`. Add styled text to the feature list and package overview. Keep `ROADMAP.md` free of shipped placeholders and state that no additional capabilities are currently planned. Do not add deprecated aliases or compatibility wrappers.

- [ ] **Step 3: Run all automated simulator tests**

```bash
xcodebuild -quiet -scheme ITextKit -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test
```

Expected: all Core, UIKit, and SwiftUI test targets pass.

- [ ] **Step 4: Validate documentation, formatting, and diff scope**

```bash
xcodebuild -quiet -scheme ITextKit -destination 'generic/platform=iOS Simulator' docbuild
git diff --check
git status --short
```

Expected: DocC build exits 0, `git diff --check` prints nothing, and status lists only intended styled-text/release files.

- [ ] **Step 5: Commit the documented 0.3.0 release state**

```bash
git add README.md ROADMAP.md Sources/ITextKit/Documentation.docc docs/performance/0.3.0-styled-text.md
git commit -m "chore: release 0.3.0"
```

- [ ] **Step 6: Verify the release commit before publication**

```bash
git status --short
git log -1 --oneline
git tag --list 0.3.0
```

Expected: worktree is clean, the last commit is `chore: release 0.3.0`, and no existing `0.3.0` tag is printed.

- [ ] **Step 7: Create and atomically publish the annotated tag**

```bash
git tag -a 0.3.0 -m "ITextKit 0.3.0"
git push --atomic origin main 0.3.0
```

Expected: both `main` and tag `0.3.0` are accepted in one atomic push.

- [ ] **Step 8: Verify remote branch and peeled tag separately**

```bash
git ls-remote origin refs/heads/main refs/tags/0.3.0 refs/tags/0.3.0^{}
git rev-parse HEAD
```

Expected: `refs/heads/main` and `refs/tags/0.3.0^{}` equal the local `HEAD`; `refs/tags/0.3.0` is the annotated tag object and may have a different SHA.
