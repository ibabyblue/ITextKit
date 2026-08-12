# ITextKit Styled Text Design

Date: 2026-08-12

Status: Approved

Target release: 0.3.0

## Summary

ITextKit will add exact outward text strokes, solid and linear-gradient fills, and solid and linear-gradient strokes for UIKit and SwiftUI. The new styling composes with rotator, marquee, typewriter, and shimmer effects while preserving the package's iOS 15 minimum and its existing unstyled behavior.

The package will not claim that it can transparently modify an arbitrary SwiftUI `Text`. SwiftUI does not expose the resolved font and glyph outline of an existing `Text`, including through the public iOS 18 `TextRenderer` interface. SwiftUI therefore receives a dedicated `ITextStyledText` view backed by the same CoreText renderer as UIKit.

## Goals

- Express stroke width as the final visible outward thickness in logical points.
- Support solid or linear-gradient fill and solid or linear-gradient stroke in the first release.
- Apply one continuous gradient across the complete rendered text bounds, including multiline text.
- Preserve native text measurement, wrapping, truncation, baseline, Dynamic Type, RTL, and accessibility behavior within the documented interface.
- Compose styled text with all existing ITextKit effects.
- Avoid production-generated text images, pattern-image colors, per-frame text layout, and unbounded caches.
- Keep one Swift Package product, one target, and one `import ITextKit` surface.

## Non-goals

- Radial, angular, or conic gradients.
- Gradient color or position animation.
- Per-line gradients.
- Per-range ITextKit gradient or stroke styles.
- New shadow or glow styling interfaces.
- A transparent `Text.iTextStroke(...)` modifier for arbitrary SwiftUI `Text` values.
- Text editing, selection, link interaction, or dedicated attachment styling.
- Canvas, Metal, or third-party rendering dependencies.

## Package and Module Structure

The feature remains in the existing `ITextKit` package and product. Text styling is part of the same text-presentation responsibility as rotation, marquee, typewriter, and shimmer.

Internally, the design introduces a deep rendering Module behind one seam:

```text
Public style values
ITextStyle / ITextPaint / ITextStroke / ITextLinearGradient
                         |
                         v
Shared CoreText rendering Module
layout, measurement, glyph paths, drawing plan, bounded caching
                         |
              +----------+----------+
              |                     |
              v                     v
ITextStyledLabel             ITextStyledText
UIKit Adapter                SwiftUI Adapter
```

The shared rendering Module owns every rule that can affect cross-framework parity. UIKit and SwiftUI Adapters may translate platform input and lifecycle state, but they must not implement independent stroke, gradient, or measurement algorithms.

Proposed source layout:

```text
Sources/ITextKit/Core/
  ITextStyle.swift
  ITextLinearGradient.swift

Sources/ITextKit/Internal/StyledText/
  ITextAttributedContent.swift
  ITextLayoutEngine.swift
  ITextLayoutResult.swift
  ITextGlyphPathCache.swift
  ITextDrawingPlan.swift
  ITextDrawingLayer.swift

Sources/ITextKit/UIKit/
  ITextStyledLabel.swift

Sources/ITextKit/SwiftUI/
  ITextStyledText.swift
```

The filenames describe responsibilities, not mandatory implementation type names. Internal types remain non-public unless a caller-visible contract requires them.

## Public Style Interface

The shape of the style is shared while each framework keeps its native color type:

```swift
public enum ITextPaint<ColorValue> {
    case solid(ColorValue)
    case linearGradient(ITextLinearGradient<ColorValue>)
}

public struct ITextStroke<ColorValue> {
    public var paint: ITextPaint<ColorValue>
    public var width: CGFloat
}

public struct ITextStyle<ColorValue> {
    public var fill: ITextPaint<ColorValue>?
    public var stroke: ITextStroke<ColorValue>?
}

public typealias ITextUIKitStyle = ITextStyle<UIColor>
public typealias ITextSwiftUIStyle = ITextStyle<Color>
```

`fill == nil` preserves the existing foreground colors. `stroke == nil` adds no ITextKit stroke. The renderer never mutates caller-owned attributed input.

### Linear gradients

```swift
public struct ITextGradientStop<ColorValue> {
    public var color: ColorValue
    public var location: CGFloat
}

public struct ITextLinearGradient<ColorValue> {
    public var stops: [ITextGradientStop<ColorValue>]
    public var startPoint: ITextGradientPoint
    public var endPoint: ITextGradientPoint
}
```

The type provides both a `stops:` initializer and a `colors:` convenience initializer that distributes colors evenly.

`ITextGradientPoint` provides semantic anchors such as `.leading`, `.trailing`, `.top`, `.bottom`, and corner combinations. Semantic leading and trailing resolve against the current layout direction. `.unit(x:y:)` is an explicit physical normalized coordinate and does not mirror in RTL.

Both fill and stroke resolve their gradients in the final visible ink bounds, including outward stroke space. Multiline text shares one coordinate space; the gradient does not restart for each line or attributed run. Fill and stroke may use different paints and directions.

### Stroke semantics

`ITextStroke.width` is the final visible outward thickness in logical points. For a public width `w`, the renderer constructs a centered outline with width `2w`, then draws the fill above it to cover the inner half. A public value of `2` therefore expands the visible glyph by 2 points on each edge.

Stroke joins and caps are renderer-owned and use round joins and round caps to prevent font-outline spikes. They are intentionally absent from the first public interface.

## UIKit Adapter

`ITextStyledLabel` is a `UILabel` subclass with one new primary property:

```swift
@MainActor
public class ITextStyledLabel: UILabel {
    public var textStyle: ITextUIKitStyle?
}
```

It retains the relevant `UILabel` interface, including:

- `text`, `attributedText`, `font`, and `textColor`
- `numberOfLines`, `lineBreakMode`, and `textAlignment`
- `preferredMaxLayoutWidth`
- `adjustsFontSizeToFitWidth`, `minimumScaleFactor`, baseline adjustment, and truncation tightening
- `adjustsFontForContentSizeCategory`
- intrinsic content size, `sizeThatFits`, compression resistance, content hugging, and baseline anchors
- `shadowColor` and `shadowOffset`
- one native accessibility element

When `textStyle == nil`, the label calls the native `UILabel` path. This is the compatibility and zero-overhead path. When a style exists, the shared rendering Module supplies measurement and drawing.

Arbitrary `UILabel` instances do not receive associated-object properties, method swizzling, or behavior-changing global extensions. A plain `UILabel` must be changed to `ITextStyledLabel` to obtain exact styling.

Example:

```swift
let label = ITextStyledLabel()
label.text = "Fantasia"
label.font = .systemFont(ofSize: 28, weight: .bold)
label.textStyle = ITextUIKitStyle(
    fill: .linearGradient(fillGradient),
    stroke: .init(
        paint: .linearGradient(strokeGradient),
        width: 2
    )
)
```

## SwiftUI Adapter

`ITextStyledText` is a dedicated SwiftUI `View`. It is not a `Text` extension and does not attempt to inspect an opaque existing `Text` value.

Plain input uses a `UIFont` parameter rather than an opaque SwiftUI `Font`:

```swift
ITextStyledText(
    "Fantasia",
    font: .systemFont(ofSize: 28, weight: .bold),
    style: style
)
```

The public initializer defaults to `UIFont.preferredFont(forTextStyle: .body)` and enables scaling of its default font with the SwiftUI Dynamic Type environment. Supplying another `UIFont` remains explicit and testable:

```swift
public init(
    _ text: String,
    font: UIFont = .preferredFont(forTextStyle: .body),
    style: ITextSwiftUIStyle,
    adjustsFontForContentSizeCategory: Bool = true
)
```

Rich styled input uses `NSAttributedString`, with a default `UIFont` for ranges that do not contain a font:

```swift
public init(
    attributedText: NSAttributedString,
    defaultFont: UIFont = .preferredFont(forTextStyle: .body),
    style: ITextSwiftUIStyle,
    adjustsFontForContentSizeCategory: Bool = true
)
```

The first version intentionally does not accept SwiftUI `AttributedString` for the styled path because SwiftUI `Font` cannot be reliably resolved back to the exact CoreText font on the iOS 15 deployment contract. Existing unstyled SwiftUI controls continue to accept native `AttributedString`. Explicit fonts inside `NSAttributedString` remain caller-owned; the scaling flag defaults to `true` for the SwiftUI Adapter and applies to the default font, while explicitly attributed fonts follow the same caller-owned rule as UIKit.

The Adapter reads public SwiftUI environment values that have deterministic equivalents, including layout direction, line limit, multiline alignment, Dynamic Type category, display scale, and accessibility state. Typography still comes from its initializer or attributed content; an outer `.font(...)` does not alter styled text.

The view participates normally in stacks and accepts outer layout and decoration modifiers such as `frame`, `padding`, `background`, `opacity`, and transforms. Without a width constraint it uses its ideal content size. With a width proposal it wraps and reports the corresponding height. Outward stroke space is part of the reported size.

## Layout Interface and Data Flow

The internal layout seam accepts an immutable attributed snapshot plus resolved layout constraints and returns an immutable result. Inputs include:

- characters and supported inline attributes
- default font and foreground color
- proposed text width after stroke insets
- maximum line count and line-break mode
- alignment and resolved layout direction
- font scaling and tightening settings
- display scale

The result contains:

- typographic bounds and visible ink bounds
- first and last baseline positions
- line, run, glyph, decoration, and fallback-drawing records
- positioned glyph paths
- truncation state
- the final size including outward stroke

Layout never owns animation state and never reads global lifecycle state. This keeps it deterministic and directly testable through the same seam used by both Adapters.

### Automatic and constrained sizing

For automatic sizing, the base typographic and ink bounds are measured first and then expanded by the resolved outward stroke. Fill geometry is not compressed.

For an explicitly constrained total width, the renderer reserves one stroke width on the leading edge and one on the trailing edge before laying out glyphs. This prevents clipping and can cause earlier wrapping than the same fixed-width text without stroke. The behavior is deliberate because the stroke is visible content.

Empty content has zero size and creates no paths or animation. Baseline values include the top stroke inset so baseline constraints align the rendered text, not an unexpanded hidden box.

## Drawing Pipeline

The renderer builds a drawing plan only after layout changes. The order is fixed:

1. Resolve the final visible gradient coordinate space.
2. Draw the stroke shape.
3. Draw glyph fill above the stroke, hiding its inner half.
4. Draw underline and strikethrough decorations.
5. Draw native fallback runs such as color glyphs.
6. Let shimmer add its optional highlight treatment.
7. Let marquee or rotator transform the completed styled result.

Solid paint uses direct Core Graphics color drawing. Linear-gradient paint clips to the appropriate glyph or stroked-glyph path and draws one `CGGradient` over the complete visible text bounds. Production code does not create a `UIImage`, pattern-image color, view snapshot, or permanent raster cache. Normal system rasterization into a view or layer backing store is expected and is not an image-generation strategy.

CoreText performs shaping and line layout. `CTFontCreatePathForGlyph` supplies outline paths where the font supports them. Glyphs without a usable outline, particularly color Emoji, use native run drawing, retain their native color, and do not receive ITextKit gradient or stroke treatment. Attachments use the native fallback path when available and otherwise retain the package's existing no-dedicated-support contract.

Underline and strikethrough geometry is preserved. If a decoration has an explicit color, it keeps that color. Otherwise it follows the effective fill. ITextKit stroke does not outline underline or strikethrough paths.

## Attributed-Text Precedence

The supported rich-text contract continues to cover font, foreground color, kern, underline, strikethrough, baseline, and UIKit paragraph style.

Precedence is deterministic:

- `style.fill == nil` preserves per-run foreground colors.
- A non-`nil` style fill uniformly replaces glyph foreground colors without mutating input.
- `style.stroke == nil` adds no ITextKit stroke and preserves native per-run stroke attributes under their system percentage-of-font semantics, including in a styled fill path.
- A non-`nil` ITextKit stroke replaces native attributed stroke drawing in the styled path so percentage-of-font and real-point semantics cannot stack.
- Font, kern, baseline, ligature, paragraph, underline, and strikethrough attributes remain active.
- Unknown attributes pass through to native fallback drawing but have no cross-framework guarantee.

The style is view-wide in 0.3.0. Per-range ITextKit paints are outside the first release.

## Existing Effect Integration

### UIKit

- `ITextShimmerLabel` becomes a subclass of `ITextStyledLabel` and remains transitively a `UILabel`.
- Rotator, marquee, and typewriter replace their private visual labels with styled labels.
- Each public UIKit control receives `textStyle: ITextUIKitStyle?`, defaulting to `nil`.
- Existing text, playback, lifecycle, accessibility, and reset contracts remain unchanged.

### SwiftUI

Existing initializers remain unchanged and continue to render native `Text`. Styled overloads require a nonoptional `textStyle` label, so they cannot collide with current calls; their plain-text font defaults to the preferred body font. Rich styled overloads use an explicit `styledAttributedText: NSAttributedString` label and a `defaultFont` parameter.

Styled mode uses `ITextStyledText` internally. It does not consume an outer `.font(...)`. Documentation and examples must make the distinction visible at the call site.

### Composition order

| Effect | Styled behavior |
| --- | --- |
| Rotator | Build outgoing and incoming styled results first, then animate opacity and vertical transform. Stroke affects variable height. |
| Marquee | Measure the complete styled single line. Repeated copies share the same immutable layout and gradient coordinates; each copy carries its own identical gradient while moving. |
| Typewriter | Reveal complete Swift `Character` boundaries. A full-text layout defines stable gradient coordinates, while the visible-prefix layout defines current ideal size. Gradient colors do not shift as the prefix grows. |
| Shimmer | Apply the highlight after fill and stroke composition. The moving band covers the visible alpha of both fill and stroke and remains hidden from accessibility. |

Marquee and rotator update only presentation transforms and opacity during frames. Shimmer updates only its native gradient animation. Typewriter changes layout only when another complete character becomes visible.

The existing SwiftUI `.shimmerText(...)` modifier remains available. Its highlight implementation uses the rendered content alpha as a mask so styled content can participate without relying on `foregroundStyle` to recolor an opaque platform-backed view. UIKit uses one keyed Core Animation and no timer or display link for shimmer.

## Cache and Invalidation Design

Each Adapter retains only its latest layout and drawing plan. It reuses them when content and resolved layout inputs are unchanged.

A shared bounded `NSCache` stores reusable glyph paths keyed by the resolved font identity, variation state, transform, and glyph identifier. Its initial limits are 2,048 glyph paths and an estimated 8 MiB total cost; it is cleared on memory pressure. The estimates include path element storage and key overhead and may be tuned internally only after performance evidence. No whole-view or unbounded whole-string cache is introduced.

Invalidation is separated by cost:

- Text, font, supported metrics, proposed width, line settings, Dynamic Type, or layout direction invalidate layout and drawing.
- Stroke width invalidates measurement, layout insets, and drawing.
- Paint colors, gradient stops, and trait-based color appearance invalidate drawing but not glyph layout.
- Animation progress never invalidates layout or glyph paths.
- Reassigning an equal resolved value is idempotent.

The shared Module exposes no cache controls publicly. Cache policy remains an implementation detail so it can be tuned without changing callers.

## Invalid Input Resolution

Public values preserve caller input. Render-time resolution produces finite, safe values without throwing, crashing, or logging repeatedly.

- Stroke width resolves to `0...64` points.
- Negative or non-finite stroke width resolves to `0`; values above `64` resolve to `64`.
- An empty gradient resolves as absent paint. For fill this preserves original foreground colors; for stroke it disables the stroke.
- A one-color gradient resolves as a solid color.
- Stop locations clamp to `0...1`, use stable location order, and allow duplicates for hard transitions.
- Non-finite stop locations use that stop's evenly distributed index position.
- Unit coordinates clamp to `0...1`; non-finite geometry falls back to `.leading` to `.trailing`.
- Equal start and end points resolve as the first gradient color.
- An invalid or unavailable glyph outline uses native fallback drawing.

These rules, units, valid ranges, and fallbacks are public documentation requirements.

## Accessibility and Lifecycle

- Each control exposes one accessibility element containing plain characters.
- Internal outgoing, incoming, repeated, mask, and highlight copies remain inaccessible and noninteractive.
- Typewriter exposes its complete plain value from the start.
- Shimmer disappears under Reduce Motion; static stroke and gradient remain.
- Rotator and marquee keep their existing Reduce Motion and playback behavior.
- UIKit timing remains scene-aware through the existing scene-level lifecycle observer; static styled text owns no lifecycle observer.
- Dynamic colors resolve again when the effective traits change.

## Performance Contract and Release Gates

The design does not promise zero rendering cost on every possible device and input. It instead makes performance observable and blocks release on explicit regressions.

Implementation constraints:

- No production-generated text bitmap, pattern-image color, or view snapshot.
- No permanent `shouldRasterize` shortcut.
- No timer, display link, `TimelineView`, Canvas, Metal, or per-frame Swift callback for static styling or shimmer.
- Existing motion display links update scalar presentation state only; they cannot rebuild text layout or glyph paths.
- Typewriter may build one visible-prefix layout per newly revealed Character, never one per display frame.
- Cache sizes are bounded and memory-pressure aware.

Release measurements use an optimized build on a physical iPhone 12, or on the oldest available supported physical device when it is not newer than iPhone 12. A newer-only measurement is diagnostic evidence, not a substitute for this release gate. Results record device, OS, sample count, and input, and use at least three runs after one warm-up run:

- A 100-glyph multiline sample with gradient fill and gradient stroke must have cold layout-and-plan p95 at or below 4 ms over at least 100 iterations.
- Reusing unchanged content and layout must have p95 at or below 1 ms.
- Ten simultaneously running styled marquee or shimmer samples must produce zero layout or glyph-path rebuilds after animation startup during a 10-second run.
- A 20-row styled-text scrolling fixture is compared with an otherwise identical native `UILabel` fixture. Styled p95 frame time may not exceed the baseline by more than 1 ms, and no ITextKit layout or path-building interval may block the main thread for more than one 60 Hz frame (16.67 ms).
- The warm glyph cache must remain within its configured count and cost limits throughout stress testing.

If a threshold fails, 0.3.0 is not published until the implementation is optimized or the design is explicitly revised and reapproved.

## Testing Strategy

### Core tests

- Stroke normalization and exact outward geometry at 0, 0.5, 1, 2, and 3 points.
- Gradient stop normalization, one-color behavior, empty behavior, and equal-point behavior.
- Semantic gradient anchors in LTR and RTL; physical unit points do not mirror.
- Single-line and multiline layout, wrapping, truncation, alignment, baselines, and stroke-expanded bounds.
- English, Chinese, Arabic, ligatures, combining marks, extended grapheme clusters, mixed fonts, and color Emoji fallback.
- Layout and glyph cache hit, invalidation, limit, and memory-warning behavior.

### UIKit tests

- `ITextStyledLabel` intrinsic size, `sizeThatFits`, Auto Layout, baseline anchors, Dynamic Type, and trait changes.
- `textStyle == nil` follows the native path and preserves current output.
- Styled rotator, marquee, typewriter, and shimmer keep existing playback, lifecycle, RTL, accessibility, and reset contracts.
- Caller-owned mutable attributed strings remain unmodified.

### SwiftUI tests

- Public interface compilation for plain and rich styled content.
- Ideal sizing without a width proposal and automatic height with a width constraint.
- Standard `lineLimit`, multiline alignment, RTL, Dynamic Type, outer layout, and accessibility modifiers.
- Explicit verification that outer `.font(...)` does not silently alter styled typography.
- All four existing effects render styled content without duplicate accessibility elements.

### Visual and mutation tests

Production views are rendered through existing test techniques; no production-only test interface is added.

- Pixel bounds verify true outward expansion for 0, 0.5, 1, 2, and 3 points.
- Samples cover solid fill, gradient fill, solid stroke, gradient stroke, and gradient fill plus gradient stroke.
- Multiline samples verify one continuous gradient rather than a per-line restart.
- RTL samples verify semantic mirroring and physical-unit stability.
- Mutation checks prove that changing stroke width, paint, font, container width, and traits affects the intended pixels and geometry.
- Combination fixtures cover styled rotator, marquee, typewriter, and shimmer in UIKit and SwiftUI.
- Rendering counters prove that warm animation frames do not cause layout or glyph-path reconstruction.

All existing package tests must remain green through the iOS Simulator package scheme. The executable automated gate is `xcodebuild test -scheme ITextKit` against an available iOS Simulator; host `swift test` is not a valid gate because this iOS-only package imports UIKit and the macOS build fails with `no such module 'UIKit'`. Simulator tests, DocC validation, `git diff --check`, visual inspection, and the performance gates are required before release.

## Compatibility and Release

This is an additive minor release, `0.3.0`.

- Existing public initializers and properties remain source compatible.
- Existing SwiftUI `AttributedString` paths remain native and unchanged.
- Existing controls default to `textStyle == nil` and retain their current rendering path.
- No compatibility wrappers or deprecated aliases are added without an observed consumer need.
- README and DocC add styled-text examples, units, valid ranges, fallback rules, modifier ordering, accessibility behavior, and performance characteristics.
- Roadmap records no remaining placeholder after the capability ships.

Release work includes validation, a focused release commit, an annotated `0.3.0` tag, atomic push, and separate verification that remote `main` and the peeled tag reference point to the release commit.

## Acceptance Criteria

The feature is complete only when all of the following are true:

1. UIKit and SwiftUI render the approved 0, 1, 2, and 3 point visual samples with the same outward-width semantics.
2. Solid and linear-gradient fill and stroke work independently and together.
3. Multiline gradients are continuous across the final visible text bounds.
4. Styled text auto-sizes and wraps according to the documented stroke-space rules.
5. Rotator, marquee, typewriter, and shimmer compose with styled text in both frameworks.
6. Native color Emoji remain visible and are not converted to monochrome outlines.
7. Accessibility, RTL, Dynamic Type, scene lifecycle, Reduce Motion, and existing playback contracts pass regression tests.
8. Animation frames do not rebuild layout or glyph paths after startup, except typewriter at Character boundaries.
9. The documented performance gates pass on recorded reference hardware.
10. Existing unstyled calls retain their current interface and rendering behavior.
