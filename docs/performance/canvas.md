# Image Canvas performance validation

Measured on 2026-11-18 against the implementation committed as `da601f3`, included in
ITextKit 0.4.0. Release preparation changes documentation only; these measurements cover
`ITextCanvasView` / `ITextCanvas` and retain their original environment and limits.

## Design and optimization

The native editor uses TextKit 1 with floating `UIImageView`s and rotated rectangular
exclusion paths. A separate, cached text-only layout supplies image anchors, so wrapped
text cannot feed back into image positioning. Gesture poses are transient until release.
Repeated gesture updates are coalesced by UIKit layout; bitmaps and image views are reused.

The first implementation invalidated all text layout whenever exclusion paths changed.
The 10,000-character simulator fixture recorded a layout P95 of approximately 109.7 ms
and failed its 16.67 ms gate. A CPU sample identified exclusion-path assignment through
`textContainerChangedGeometry` and full text layout as the main hotspot. The final
implementation invalidates affected paragraphs during image manipulation, while ordinary
text, font, and width changes retain the normal layout path. It also caches the UTF-16
snapshot and character widths between text edits. A regression compares incremental
results with a freshly laid-out document across multiple translations and rotations.

## Environment and procedure

- Xcode 27.2 (27B52), Debug builds; this is not a Release certification.
- Physical device: iPhone 15 Plus, iOS 27.2.1 (24B156), app-hosted XCTest.
- Simulator: iPhone 17 Pro, iOS 26.5, package-hosted XCTest on the development Mac.
- Viewport: 390 × 650 pt, 17 pt system font, mixed Chinese/English/Arabic/emoji paragraphs.
- Fixtures: 2,000 Swift characters / 6 images and 10,000 Swift characters / 20 images.
  Images are distributed through the document; the first image is manipulated.
- Final runs use a generated, decoded 256 × 192 pt bitmap shared by the image views.
  Resource lookup and bitmap construction occur before measurement. Network loading,
  different large source photos, and decoding during scrolling are not measured.
- Layout loop: 300 translation-plus-rotation updates; discard 30 warm-up updates and
  report 270 samples. Includes `layoutIfNeeded` and text-layer `displayIfNeeded`.
- Live loop: 600 updates paced by `CADisplayLink` requesting 60 Hz (about 10 seconds).
  Work time measures the manipulation update and native layout inside the callback.
  UIKit drawing occurs between callbacks. Display-link timestamp deltas yield 599 intervals.
- Percentiles use nearest rank. The automated gate is work/layout P95 < 16.67 ms.
  Long intervals are counted when greater than 1.5 times the corresponding target interval.

## Final physical-device results

All times are milliseconds. All four performance tests passed.

| Fixture | Layout P50 | Layout P95 | Layout max | Live work P50 | Live work P95 | Live work max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 2,000 characters / 6 images | 1.610 | 3.308 | 3.394 | 5.407 | 10.648 | 12.316 |
| 10,000 characters / 20 images | 1.811 | 1.892 | 1.974 | 6.067 | 7.345 | 13.707 |

| Fixture | Interval P95 | Interval max | Target interval P95 | Long intervals |
| --- | ---: | ---: | ---: | ---: |
| 2,000 / 6 | 16.647 | 16.783 | 16.647 | 0 / 599 |
| 10,000 / 20 | 16.669 | 18.449 | 16.669 | 0 / 599 |

Each 300-update run produced zero baseline rebuilds and 300 exclusion updates.
Image-provider calls were exactly 6 and 20 respectively, all from the initial explicit
reload, with no per-frame lookups. Different fixtures encounter different affected
paragraphs and wrapping transitions; P95 need not increase with total document length.

## Final simulator results

All four performance tests passed their P95 gates; the stress live loop had long outliers.

| Fixture | Layout P50 | Layout P95 | Layout max | Live work P50 | Live work P95 | Live work max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 2,000 / 6 | 2.268 | 6.599 | 7.062 | 2.834 | 7.491 | 19.286 |
| 10,000 / 20 | 5.656 | 6.552 | 9.313 | 6.175 | 8.085 | 83.301 |

| Fixture | Interval P95 | Interval max | Long intervals |
| --- | ---: | ---: | ---: |
| 2,000 / 6 | 16.667 | 20.204 | 0 / 599 |
| 10,000 / 20 | 16.667 | 88.874 | 7 / 599 (1.17%) |

The simulator also recorded zero baseline rebuilds and only initial resource lookups.
These outliers are reported without assigning an unproven cause to host scheduling.

## Correctness and UI validation

- Full package regression: 155 tests passed, followed by one additional passing test
  verifying gesture commit preserves the last rendered layout without another reflow.
  The final bitmap-bearing performance fixture was then rerun separately on both targets.
- Coverage includes document serialization, UTF-16 anchor edits, Chinese marked input,
  cancellation, shared undo/redo, collision rejection, resource reload, ownership release,
  read-only rendering, no-op layout, SwiftUI binding echoes, and object deallocation.
- Native glyph raster checks at 0°, 30°, 45°, 90°, 135°, and 270° verify that visible text
  ink stays outside image interiors. Arabic paragraph advancement is also checked.
  RTL paragraphs use one native fragment per row to avoid TextKit 1 split-row overlap.
- Geometry and edit/read parity are checked at 320, 375, 390, 430, and 768 pt widths.
- Two XCUI canvas tests passed: real long-press drag, two-finger rotation, undo/redo,
  save/restore, read-only gesture rejection, SwiftUI binding and keyboard text entry.
  Both seven-topic catalog tests passed after scrolling to the off-screen seventh entry.
- UIKit and SwiftUI screenshots were inspected, including the keyboard-visible layout.
- DocC build and `git diff --check` passed.

## Reproduction

The same `Tests/ITextKitUIKitTests/ITextCanvasPerformanceTests.swift` source is included in
the Example app-hosted performance target. Substitute available destinations and signing team:

```sh
xcodebuild -scheme ITextKit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug test \
  -only-testing:ITextKitUIKitTests/ITextCanvasPerformanceTests \
  CODE_SIGNING_ALLOWED=NO

xcodebuild -project Example/ITextKitExample.xcodeproj -scheme ITextKitExample \
  -destination 'platform=iOS,id=<device-udid>' \
  -configuration Debug test \
  -only-testing:ITextKitExamplePerformanceTests/ITextCanvasPerformanceTests \
  DEVELOPMENT_TEAM=<team-id>
```

`CANVAS_METRIC` output and retained XCTest text attachments contain raw timing summaries.
Local validation logs for this session are under `/private/tmp/`:

- `itextkit-canvas-textured-device-tests.log` and `itextkit-canvas-textured-sim-tests.log`
- `itextkit-canvas-final-full-tests.log` and `itextkit-canvas-commit-tests.log`
- `itextkit-canvas-final-ui-tests.log` (canvas tests passed; catalog failure superseded by
  `itextkit-canvas-catalog-retest.log`)
- `itextkit-canvas-docbuild.log`

## Limits

The sampled physical-device run meets the 60 Hz work budget with no sampled long intervals.
Display-link timing does not measure GPU presentation or guarantee absence of compositor
hitches. There is no Instruments GPU/animation-hitch recording, energy measurement,
long-duration thermal soak, or large-photo memory benchmark in this validation.
The release/deallocation regression is not a peak-memory measurement. Older devices,
iOS 15 runtime behavior, 120 Hz targets, and documents larger than these fixtures remain
unmeasured. Very long single paragraphs can require more work than this paragraph-based
fixture. Keep image loading/decoding outside the provider callback and validate production
assets and document distributions when adopting the component.
