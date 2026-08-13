# ITextKit Example API Catalog Design

**Date:** 2026-08-13
**Status:** Approved for implementation planning

## Objective

Replace the two chronological, long-form Example pages with a complete API
teaching catalog. SwiftUI and UIKit remain separate platform experiences. Each
public component gets a focused detail page containing live examples, behavior
and parameter explanations, complete copyable code, and usage notes.

The catalog covers every meaningful public use rather than every possible
parameter combination. Styled text must be visible in the normal application;
the hidden physical-performance fixture is retained only for automated
profiling.

This work changes only the Example application, its documentation, generated
Xcode project, and Example tests. It does not add or change ITextKit public API.

## Information Architecture

The root remains a two-tab application:

```text
ITextKit Example
├── SwiftUI
│   ├── Styled Text
│   ├── Rotator
│   ├── Marquee
│   ├── Typewriter
│   ├── Shimmer
│   └── Accessibility & Environment
└── UIKit
    ├── Styled Label
    ├── Rotator View
    ├── Marquee View
    ├── Typewriter View
    ├── Shimmer Label
    └── Accessibility & Environment
```

The minimum deployment target remains iOS 15. The SwiftUI tab uses an iOS
15-compatible SwiftUI navigation container. The UIKit tab enters the SwiftUI
root only through one `UIViewControllerRepresentable`; its catalog,
navigation, detail pages, example cards, controls, and code blocks are UIKit.
UIKit examples are not reimplemented as SwiftUI views.

Catalog rows show a component name, one-sentence purpose, and capability tags
such as `Attributed`, `Styled`, `Playback`, `RTL`, or `Dynamic Type`. Styled
text appears first because Rotator, Marquee, Typewriter, and Shimmer compose
with it.

Every detail page follows the same teaching order:

1. Purpose and explicit behavior boundary.
2. One or more live examples.
3. Relevant parameters or playback controls.
4. Complete code for each example.
5. Usage notes and platform-specific pitfalls.

## Example Infrastructure

Shared, presentation-neutral values live under `Example/ITextKitExample/Shared`:

- `DemoSnippet`: stable identifier, title, summary, capability tags, and code.
- `DemoCapability`: the finite set of catalog tags.

The rendered UI remains platform-specific:

- SwiftUI owns `SwiftUIDemoCard`, `SwiftUIDemoSection`,
  `SwiftUIDemoCodeBlock`, and SwiftUI detail views.
- UIKit owns `UIKitDemoCardView`, `UIKitDemoSectionView`,
  `UIKitDemoCodeView`, and UIKit detail view controllers.

Code is stored beside the live example that it documents, in the same source
file. A code block uses a monospaced font, preserves indentation, scrolls
horizontally instead of wrapping long API calls, and provides a Copy action.
Copying writes the complete snippet to the system pasteboard and changes the
button feedback to `Copied` without introducing a toast dependency.

Example-only helpers do not leak into the package target. Example screens use
public ITextKit APIs; app-hosted performance tests retain `@testable` access to
internal counters without creating a production test seam.

## SwiftUI Catalog

### Styled Text

The page demonstrates:

- Native `Text` as a sizing and visual reference.
- Solid replacement fill.
- Horizontal continuous linear-gradient fill.
- Solid outward strokes at 0.5, 1, 2, and 3 points.
- Linear-gradient stroke.
- Linear-gradient fill and gradient stroke together.
- `NSAttributedString` plus explicit `UIFont` input.
- Multiline gradient continuity.
- Semantic leading/trailing versus physical `.unit(x:y:)` gradient points.
- Styled text followed by `.shimmerText()` and then outer decoration.

Notes explain that stroke width is the final visible outward thickness in
points, an unconstrained width `w` adds approximately `2w` to total width and
height without squeezing the fill, and outer SwiftUI `.font(...)` does not
alter `ITextStyledText`.

### Rotator

The page demonstrates plain, attributed, and styled input; variable-height
content; `ITextPlaybackState`; and `.onTextRotatorChange`. Start, Pause,
Resume, and Stop controls update the shared playback value, while Start also
recreates the sample to demonstrate a fresh cycle.

### Marquee

The page demonstrates fitting static text, overflowing looping text,
attributed input, styled input, speed, spacing, initial delay, playback state,
and an explicit RTL specimen. It states that one-line content is required and
that semantic motion direction follows layout direction.

### Typewriter

The page demonstrates plain, attributed, and styled input; caller-constrained
wrapping; intrinsic width and height growth; Emoji and composed-character
safety; and Replay through view identity. It does not add playback controls to
the public one-shot API.

### Shimmer

The page demonstrates native `Text`, attributed content, styled fill and
stroke, `isActive`, duration, band width, intensity, direction, and highlight
color. One paired example shows correct modifier order: typography and text
styling, shimmer, then frame/padding/background.

### Accessibility & Environment

The page demonstrates local LTR/RTL specimens, selected Dynamic Type sizes,
current system Reduce Motion status, and VoiceOver ownership notes. It may
override SwiftUI layout direction and Dynamic Type inside individual specimen
containers. It does not claim to override the operating system's Reduce Motion
or VoiceOver state.

## UIKit Catalog

UIKit pages mirror the same concepts using their native APIs rather than
sharing SwiftUI example bodies.

### Styled Label

The page demonstrates native `UILabel` reference rendering; solid and gradient
fill; 0.5, 1, 2, and 3 point solid strokes; gradient stroke; combined gradient
fill and stroke; attributed content; multiline continuity; Auto Layout;
intrinsic sizing; and normal `UILabel` properties. Examples make clear that
`ITextStyledLabel` automatically sizes like a label and reserves outward stroke
space.

### Rotator View

The page demonstrates plain, attributed, and styled content; variable height;
`start()`, `pause()`, `resume()`, and `stop()`; `onTextChange`; and Dynamic
Type through preferred fonts.

### Marquee View

The page demonstrates fitting and overflowing content, attributed and styled
content, configuration values, inherited RTL via `semanticContentAttribute`,
and imperative playback methods.

### Typewriter View

The page demonstrates plain, attributed, and styled content, width constraints,
Auto Layout height growth, composed characters, and Replay by assigning fresh
input. It does not present unsupported pause or resume behavior.

### Shimmer Label

The page demonstrates plain, attributed, and styled content, including a
linear-gradient fill and stroke mask; `isShimmering`; configuration;
highlight color; intrinsic size; and accessibility ownership.

### Accessibility & Environment

The page demonstrates forced LTR/RTL specimen containers, preferred fonts and
content-size-category response, current `UIAccessibility.isReduceMotionEnabled`
status, and label accessibility values. It explains how to change system
settings for a real end-to-end Reduce Motion or VoiceOver check.

## State and Data Flow

Each detail page owns only the state needed by its examples. Catalog navigation
does not share playback state across pages. Leaving a page destroys its local
examples, and returning creates a predictable initial state.

SwiftUI playback controls bind directly to `ITextPlaybackState`. UIKit buttons
call the corresponding public methods on every sample in that section. Replay
uses the existing supported mechanism for each platform. No timer, polling,
or compatibility wrapper is added at the Example layer.

The normal application launch always shows the catalog. The
`-ITextStyledPerformance` argument continues to select the isolated 20-row
profiling fixture and bypasses the catalog.

## Accessibility and Layout

- Catalog rows and controls have stable accessibility identifiers for UI tests.
- Every live text effect remains the single accessibility owner defined by the
  production component.
- Decorative cards and code syntax do not create duplicate spoken content.
- Copy buttons have labels that identify the associated example.
- Detail pages support Dynamic Type and scrolling without fixed screen-height
  assumptions.
- Code blocks scroll horizontally and remain vertically content-sized.
- UIKit constraints use the scroll view content and frame layout guides.
- SwiftUI examples use their natural/intrinsic size unless an example is
  specifically teaching a caller-provided width constraint.

## Documentation

`Example/README.md` changes from a chronological description to a catalog map.
It documents how to generate and run the project, the platform separation,
the complete page list, the code-copy behavior, and the hidden performance
launch argument for maintainers.

## Test Strategy

Implementation follows red-green-refactor. UI tests first describe the new
catalog and fail against the existing long pages.

Required automated coverage:

1. SwiftUI and UIKit catalogs each expose six navigable entries.
2. Every detail page exposes its purpose, at least one live example, and a code
   block with a Copy action.
3. Copy changes visible feedback to `Copied` and retains the complete snippet.
4. Styled pages expose solid/gradient fill, 0.5/1/2/3 point strokes, gradient
   stroke, combined style, attributed input, multiline, and RTL specimens.
5. Rotator and Marquee controls preserve their existing playback regression
   coverage after navigation changes.
6. Typewriter Replay and composed-character examples remain present.
7. Shimmer examples cover plain and styled content plus correct decoration
   ordering.
8. Environment pages expose RTL, Dynamic Type, Reduce Motion, and VoiceOver
   teaching specimens without falsifying system state.
9. Existing retained screenshots are updated to navigate through the catalog
   and capture representative SwiftUI/UIKit detail pages.
10. The hidden 20-row performance launch-argument UI test remains green.

Release-level verification runs:

- The full ITextKit package simulator suite, serially if parallel execution is
  noisy.
- The full Example UI test suite.
- The app-hosted performance regression suite.
- Example Debug and Release builds.
- ITextKit DocC build.
- `git diff --check` and an intended-scope status audit.

Physical-device performance profiling is not repeated because this change does
not alter the package renderer or the retained profiling fixture. If the
fixture or production renderer changes during implementation, the 0.3.0 device
gate must be rerun before claiming equivalent evidence.

## Non-Goals

- No new ITextKit public API.
- No radial or conic gradients, animated gradients, Markdown, or link handling.
- No generic live code compiler or editable playground.
- No exhaustive color, speed, duration, or font permutation matrix.
- No fake switch for system VoiceOver or Reduce Motion.
- No dependency for syntax highlighting, banners, toasts, or navigation.
