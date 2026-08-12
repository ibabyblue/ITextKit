# Styled Text

Render continuous linear-gradient fill and exact outward outlines without rasterizing text.

## UIKit

``ITextStyledLabel`` is a `UILabel` subclass. When `textStyle` is `nil`, drawing and sizing use the native UILabel path. A style switches glyph rendering to CoreText/Core Graphics while the label remains the only layout, interaction, and accessibility owner.

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

Rotator, marquee, typewriter, and shimmer UIKit controls expose the same `textStyle` property.

## SwiftUI

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

The styled path accepts `String` or `NSAttributedString` with `UIFont`. It cannot transparently inspect arbitrary native `Text` or SwiftUI `Font`, and outer `.font(...)` intentionally has no effect. Pass `font` or `defaultFont` explicitly. Default fonts may scale with Dynamic Type; explicit attributed font runs remain caller-owned.

Styled effect overloads use `textStyle:` for plain content and `styledAttributedText:` or `styledAttributedTexts:` for rich content, keeping them unambiguous from native `AttributedString` initializers.

## Stroke Geometry

`ITextStroke.width` is the visible thickness outside every glyph, in points. Rendering draws an internal centered line of twice that width and then draws the fill above it. An unconstrained `w`-point stroke adds `2w` to total width and height without reducing the fill. Finite widths resolve to `0...64`; negative and non-finite widths resolve to zero.

## Gradients and Rich Text

One gradient spans the complete rendered text bounds, including every line; it does not restart per glyph, run, or line. Semantic leading/trailing points mirror in right-to-left layout. Physical `.unit(x:y:)` points remain unchanged. Stops are clamped and stably sorted; empty gradients are absent and a one-color gradient becomes solid.

CoreText shaping preserves mixed fonts, kern, ligatures, baselines, paragraph styles, underline, strikethrough, and native stroke attributes. Color Emoji and glyphs without vector outlines use the native fallback run. Caller-owned attributed strings are copied rather than mutated.

## Performance and Composition

Glyph outlines use a memory-pressure-aware cache bounded to 2,048 entries and an estimated 8 MiB. Equal paint-only changes reuse layout; font, content, width, line, direction, and outline-width changes remeasure. Motion updates transforms or masks rather than rebuilding paths per frame.

Apply text styling first, then `.shimmerText(...)`, then outer frame, padding, background, or container overlays. Shimmer masks its highlight with final rendered alpha, so fill and outline are highlighted without duplicate accessibility content.
