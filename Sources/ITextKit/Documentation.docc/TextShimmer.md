# Text Shimmer

Add a decorative highlight sweep while preserving native text behavior.

## Overview

Text shimmer renders the original text normally and reveals a private highlight-colored copy through one moving gradient band. The original remains the sole layout, sizing, hit-testing, and accessibility owner. Use ``ITextShimmerConfiguration`` to share timing and appearance choices between SwiftUI and UIKit, and ``ITextShimmerDirection`` to express travel in semantic leading and trailing terms.

## SwiftUI

Apply typography, foreground styling, line limits, and layout before `.shimmerText(...)`. This lets the modifier copy the final text presentation without taking ownership of layout:

```swift
import ITextKit
import SwiftUI

Text("Working…")
    .font(.headline)
    .foregroundStyle(.secondary)
    .shimmerText()
```

The modifier also supports `Text(AttributedString)`. Its API lives on `View` so it remains callable after standard text modifiers erase the concrete `Text` type, but its rendering contract is text content rather than arbitrary views.

Set `isActive: false` when the decoration is not requested:

```swift
Text(status)
    .font(.body)
    .lineLimit(nil)
    .shimmerText(
        isActive: isLoading,
        configuration: .init(direction: .trailingToLeading),
        highlight: .primary
    )
```

## UIKit

``ITextShimmerLabel`` subclasses `UILabel`, so callers use normal label properties and Auto Layout:

```swift
import ITextKit
import UIKit

let label = ITextShimmerLabel()
label.text = "Working…"
label.textColor = .secondaryLabel
label.highlightColor = .label
label.adjustsFontForContentSizeCategory = true
label.isShimmering = true
```

Plain and attributed content use a private mirrored `UILabel`. For `NSAttributedString`, the copy retains fonts, paragraph styles, kerning, baselines, underline, strikethrough, and other native attributes while replacing only its foreground color. The input attributed string is never mutated. Native line count, line breaking, alignment, font scaling, tightening, preferred width, and Dynamic Type settings are mirrored.

## Configuration Resolution

``ITextShimmerConfiguration`` stores the caller's exact values. Each renderer resolves values only when drawing:

| Property | Default | Renderer resolution |
|---|---:|---|
| `duration` | `1.5` seconds | finite values clamp to `0.2...10`; non-finite values use `1.5` |
| `bandWidth` | `0.28` of rendered width | finite values clamp to `0.05...1`; non-finite values use `0.28` |
| `intensity` | `0.85` opacity | finite values clamp to `0...1`; non-finite values use `0.85`; zero removes the overlay |
| `direction` | leading to trailing | resolves against the current left-to-right or right-to-left layout |

Changing active UIKit configuration rebuilds animation from the beginning. SwiftUI replaces its native animated overlay when resolved configuration or layout direction changes. Deactivating and later reactivating either API starts a complete offscreen-to-offscreen sweep instead of restoring old progress.

## Accessibility and Lifecycle

The original text is the only accessibility element. The private copy is noninteractive, hidden from accessibility, and does not intercept hit testing. VoiceOver therefore reads stable text without duplicate content or animation announcements.

When Reduce Motion is enabled, both APIs omit the decoration and keep base text visible. SwiftUI animates only while its view is presented and requested. UIKit requires nonempty text and bounds in a window; leaving the window removes its animation, and returning starts a complete sweep when ``ITextShimmerLabel/isShimmering`` is still `true`. Dynamic SwiftUI and UIKit highlight colors continue to respond to environment and trait changes.

Shimmer is controlled by `.shimmerText(isActive:)` and ``ITextShimmerLabel/isShimmering``. It intentionally does not use ``ITextPlaybackState`` because it is a repeating decoration, not deterministic content playback.

## Rendering

One gradient band traverses the complete rendered bounds, including multiline text, in the configured semantic direction. SwiftUI uses native repeating animation over a masked content copy. UIKit uses one `CAGradientLayer` mask and one keyed `CABasicAnimation`, replacing it idempotently after meaningful bounds, configuration, direction, content, or lifecycle changes.

Neither renderer owns a `Timer`, `CADisplayLink`, `TimelineView`, per-frame Swift callback, or network dependency. Removing the overlay also removes all renderer-owned animation state.
