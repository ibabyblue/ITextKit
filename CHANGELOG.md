# Changelog

All notable changes to ITextKit are documented in this file.

## 0.3.0 - 2026-08-13

### Added

- UIKit `ITextStyledLabel` and SwiftUI `ITextStyledText` with solid or linear-gradient fill and exact outward point-based outlines.
- Linear-gradient outlines, multiline continuity, semantic RTL directions, color-Emoji fallback, bounded glyph caching, and UIKit-compatible sizing.
- Styled overloads for rotator, marquee, typewriter, and shimmer in both frameworks.
- Visual geometry and cold, warm, animation, list, and cache performance regression suites.

## 0.2.2 - 2026-08-12

### Fixed

- UIKit marquee direction now follows inherited layout-direction traits.
- UIKit rotator, marquee, and typewriter timing now suspends per owning window scene, with application lifecycle fallback for apps without scenes.
- UIKit rotator and marquee now remeasure when their inherited Dynamic Type category changes.
- SwiftUI rotator change handlers now use the latest closure while the view remains mounted.

## 0.2.1 - 2026-08-10

### Added

- SwiftUI `.shimmerText(...)` and UIKit `ITextShimmerLabel` native text-highlight sweeps.
- Semantic directions, configuration normalization, rich-text preservation, Reduce Motion, lifecycle, accessibility, example, and regression coverage for shimmer.

### Fixed

- SwiftUI example modifier ordering so the highlight sweep affects text without animating its card background.

## 0.2.0 - 2026-08-09

### Added

- Independent SwiftUI `ITextTypewriter` and UIKit `ITextTypewriterView` one-shot text presentation.
- Plain and attributed typewriter input with composed-character boundaries, prefix-driven intrinsic sizing, native wrapping, lifecycle suspension, Reduce Motion completion, and full-text VoiceOver output.
- Typewriter core, SwiftUI, UIKit, example, and UI-test coverage.

## 0.1.0 - 2026-08-09

### Added

- One `ITextKit` Swift Package product and module for mixed SwiftUI and UIKit projects.
- SwiftUI `ITextRotator` and UIKit `ITextRotatorView` with content-driven height, cyclic upward cross-fade transitions, settled-item callbacks, and Reduce Motion cross-fades.
- SwiftUI `ITextMarquee` and UIKit `ITextMarqueeView` with overflow detection, seamless repeated copies, semantic right-to-left motion, and Reduce Motion static fallbacks.
- Shared configuration and playback types with exact pause/resume and lifecycle suspension semantics.
- Separate Core, SwiftUI, and UIKit test targets, DocC guides, and an offline example application.
- Native rich-text input for all four controls through SwiftUI `AttributedString` and UIKit `NSAttributedString` APIs.
- Full-attribute change detection, UIKit immutable input snapshots, native rich-text measurement, and plain-character accessibility output.
