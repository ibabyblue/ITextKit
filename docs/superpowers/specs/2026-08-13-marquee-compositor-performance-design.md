# ITextKit Marquee Compositor Performance Design

Date: 2026-08-13

Status: Approved

## Summary

ITextKit will change marquee motion from per-frame text layout and drawing to cached text presentation moved by the platform animation system. UIKit and styled SwiftUI marquee content will use Core Animation. Native SwiftUI plain and attributed content will keep native `Text` rendering while replacing per-frame observable publication with transition-driven linear animation.

The public `ITextMarquee`, `ITextMarqueeView`, configuration, and playback interfaces remain unchanged. Existing initial-delay, pause, resume, stop, RTL, Reduce Motion, Dynamic Type, accessibility, and scene-lifecycle behavior remain caller-visible contracts.

## Problem and Evidence

The current UIKit path advances a display link, publishes a new offset, calls `setNeedsLayout()`, measures text with `sizeThatFits`, and lays out two labels on every display frame. `layoutMovingLabels` also assigns `lineBreakMode` every frame. `ITextStyledLabel.lineBreakMode` invalidates styled layout without checking whether the value changed, which rebuilds its CoreText layout and drawing plan and asks its drawing layer to render again.

The styled SwiftUI marquee is a `UIViewRepresentable` around the same UIKit marquee, so both public frameworks share this hotspot. The example pages eagerly mount six specimens, normally leaving five overflowing specimens active at once even when some are outside the visible scroll viewport.

A three-second simulator Debug sample of the SwiftUI Marquee page showed:

- 82.8% process CPU at the end of the sample;
- 907 of 2,102 main-thread samples in `_ITextDrawingLayer.draw(in:)`;
- 742 samples in combined gradient-stroke path rendering;
- repeated `ITextMarqueeView.layoutSubviews -> measuredTextSize -> sizeThatFits` work.

The simulator percentage is diagnostic evidence, not a release benchmark. The call stacks establish the invalidation and redraw path that the implementation must remove.

## Goals

- Perform no text measurement, CoreText layout, drawing-plan rebuild, or glyph rasterization during steady-state marquee travel.
- Keep steady-state motion off the UIKit main-thread layout path.
- Stop publishing a SwiftUI observable snapshot on every display frame.
- Preserve native SwiftUI `Text` and `AttributedString` behavior for unstyled SwiftUI marquee content.
- Preserve exact styled-text fill and outward stroke rendering, including linear-gradient fill and stroke.
- Preserve seamless repetition, semantic RTL direction, initial delay, and exact pause/resume progress.
- Pause scene-inactive motion and resume from the frozen position.
- Preserve one accessibility element while keeping the repeated visual copy hidden from accessibility.
- Keep all public source interfaces unchanged.
- Establish a Release, physical-device performance gate using the connected iPhone SE class of hardware.

## Non-goals

- Changing speed, spacing, or delay semantics.
- Adding new public playback methods or visibility controls.
- Replacing native unstyled SwiftUI text with UIKit or CoreText rendering.
- Adding Metal, Canvas, image snapshots, or unbounded render caches.
- Changing rotator, typewriter, or shimmer timing in this work.
- Treating a lazy example page as the performance fix; the control must remain smooth when multiple instances are mounted eagerly.
- Guaranteeing suspension merely because a view is outside a scroll view's current viewport. Core Animation may cull nonvisible layers; explicit lifecycle suspension remains scene- and hierarchy-based.

## Options Considered

### Equality guards only

Adding `oldValue` guards to `ITextStyledLabel` prevents redundant invalidation and removes the worst redraw amplification. It does not remove per-frame marquee layout, measurement, or SwiftUI publication. This is necessary defensive work but is not a sufficient final design.

### Display-link transform updates

The existing deterministic engine could retain its display link while updating only a container-layer transform. This preserves behavior with limited change and should be substantially faster, but every instance still executes main-thread code every frame.

### Compositor-driven motion

The selected design computes a motion plan only when geometry or state changes and lets Core Animation or SwiftUI's animation system interpolate steady-state movement. This removes the identified per-frame layout and drawing path and gives the strongest multi-instance performance characteristics.

## Module Design

Marquee motion will be a deep internal Module behind a transition-based interface:

```text
Public input and environment events
text, style, bounds, configuration, playback, direction, lifecycle
                         |
                         v
             Marquee motion Module
       geometry + logical timeline + commands
                         |
             +-----------+-----------+
             |                       |
             v                       v
      UIKit layer Adapter     Native SwiftUI Adapter
      Core Animation          SwiftUI linear animation
             |
             v
      Styled SwiftUI Adapter
      UIViewRepresentable
```

The motion Module owns configuration normalization, overflow state, cycle distance, cycle duration, remaining initial delay, and frozen progress. It responds to discrete events rather than display frames and emits renderer commands such as static placement, reset, begin linear travel, pause, resume, and stop.

Platform Adapters own animation mechanics but do not independently calculate speed, phase, delay, or semantic direction. A monotonic clock is accepted behind an internal seam so timeline behavior is deterministic in tests.

## UIKit Adapter

`ITextMarqueeView` keeps its public type and methods. Internally it owns:

- one clipped viewport;
- one motion container with two fixed-position label copies;
- one cached content size and motion plan;
- one layer-animation Adapter.

Geometry is rebuilt only when text, font, attributed input, style geometry, bounds size, spacing, Dynamic Type, display scale, or layout direction changes. The moving labels receive their clipping mode and fixed frames during this rebuild. Their frames do not change while the marquee travels.

For a cycle distance `contentWidth + spacing` and positive speed, the Adapter installs a linear, nonautoreversing translation animation whose duration is `cycleDistance / speed`. The two copies make the animation's end-to-start wrap visually identical. LTR uses negative physical translation and RTL uses positive physical translation.

The initial delay applies once when starting or restarting, not on every repeated cycle. A fitting line, zero speed, stopped playback, or Reduce Motion renders one static tail-truncated label and installs no travel animation.

### Playback and lifecycle

- `start()` resets logical and presentation progress to semantic leading, reapplies the full initial delay, and begins travel when eligible.
- `pause()` freezes the layer using its local media time and retains the exact logical phase or remaining initial delay.
- `resume()` restores layer timing from the frozen phase without a jump.
- `stop()` removes travel animation, discards progress, and places the primary copy at semantic leading.
- Scene inactivity performs the same internal freeze as pause without changing the caller-owned playback state.
- Scene activation resumes only when caller playback is still `.playing` and motion remains eligible.
- Removal from a window removes active animation resources. Reattachment reconstructs presentation from the retained logical state.

The model layer is always assigned the canonical resting transform with implicit actions disabled before an explicit animation is installed. Presentation-layer state is never treated as the source of truth; the timeline Module computes progress from monotonic time.

## Styled Text Invalidation

All layout- or paint-affecting `ITextStyledLabel` overrides will ignore equal assignments before invalidating. Marquee code will also avoid assigning stable label properties from its steady-state path.

The styled label may rebuild layout and its drawing plan during geometry preparation. Once prepared, its drawing layer retains its backing contents while the parent motion container moves. Transform or position animation of the parent must not assign a new drawing plan or call `setNeedsDisplay()`.

These guards are correctness defenses for every styled-text consumer, not a substitute for compositor-driven marquee motion.

## SwiftUI Adapters

### Styled content

Styled SwiftUI marquee content continues through `_ITextStyledMarqueeRepresentable`, which receives the optimized `ITextMarqueeView` behavior automatically. `updateUIView` will compare resolved inputs and avoid assigning unchanged UIKit values.

### Native plain and attributed content

Unstyled SwiftUI marquee content keeps native `Text(attributedText)` so SwiftUI font, color, attributed-run, layout, and iOS 15 compatibility behavior do not regress.

The native Adapter removes the display-link-to-`@Published snapshot` loop. It uses discrete state changes to start a linear offset animation, hold a frozen offset, or reset to leading. A cancellable task schedules only delay and cycle-transition events; it does not wake on display frames. The motion Module computes the exact frozen phase from monotonic time when playback, configuration, geometry, direction, Reduce Motion, or scene state changes.

Resuming first animates the remaining partial cycle, then enters full seamless cycles. Task identity prevents stale delay or completion events from modifying a restarted view.

## Measurement and State Changes

The cached measurement key includes every value capable of changing rendered width or height. Paint-only style changes that preserve outward stroke width rebuild drawing contents but do not reset motion geometry. A stroke-width change rebuilds geometry and restarts from leading, matching the existing contract.

Viewport-width changes recompute overflow and restart from leading because the visible geometry changed. Text, attributed content, font, configuration spacing, and layout-direction changes also restart. Text color or equal-value assignments do not restart travel.

Nonfinite and negative configuration values keep their existing normalized behavior. Empty content and nonpositive cycle duration install no animation.

## Example Behavior

The public SwiftUI and UIKit Marquee pages continue showing fitting, overflowing, attributed, styled, configured, RTL, and playback behavior. They may keep all examples eagerly mounted so the catalog remains an intentional multi-instance stress case and UI-test accessibility elements remain available.

A separate performance fixture will remove unrelated catalog layout and code blocks while eagerly running at least six overflowing marquees, including native plain, attributed, RTL, and linear-gradient fill plus linear-gradient stroke variants.

## Testing

### Deterministic tests

- cycle distance and duration for normalized configuration;
- initial-delay consumption and one-time application;
- pause and resume during both delay and travel;
- stop and start reset semantics;
- scene freeze/resume without changing caller playback state;
- configuration, geometry, content, stroke-width, and RTL restart behavior;
- stale scheduled-event cancellation;
- fitting, zero-speed, empty, and Reduce Motion static behavior.

### Rendering regression tests

- UIKit moving copies receive fixed frames once and only their container transform animates;
- steady-state travel causes zero `layoutSubviews`-driven measurements;
- steady-state styled travel causes zero CoreText layout, drawing-plan, glyph-path, and drawing-layer rebuilds after warm-up;
- equal styled-label and representable updates cause no invalidation;
- native SwiftUI travel sends no per-frame `ObservableObject` publication;
- gradient fill and gradient stroke remain visually stable across the seam;
- LTR and inherited RTL move in the correct physical direction;
- accessibility exposes one element and no repeated-copy duplicate;
- start, pause, resume, stop, Reduce Motion, Dynamic Type, and scene transitions preserve current contracts.

Internal counters may be compiled through `ENABLE_TESTABILITY=YES` for app-hosted tests. No public instrumentation interface will be added.

### Physical-device performance gate

Run a Release, arm64, app-hosted fixture on the connected iPhone SE for at least 30 steady-state seconds after warm-up. The release gate requires:

- zero text-layout rebuilds during steady travel;
- zero drawing-plan and glyph-path rebuilds during steady travel;
- zero `_ITextDrawingLayer.draw(in:)` calls caused by travel after warm-up;
- zero Animation Hitches events in the steady-state interval;
- 59 to 60 displayed surface swaps per complete steady-state second on the 60 Hz device;
- no sustained ITextKit text-layout or drawing hotspot in Time Profiler;
- process sampling equivalent at or below 10% of one CPU core for the isolated six-marquee fixture.

Simulator measurements remain diagnostic only. A successful build or simulator test does not satisfy the physical-device performance gate.

## Delivery Sequence

1. Add deterministic timeline and invalidation regression tests that fail on the current implementation.
2. Add equality guards and cached geometry, then prove redundant layout and drawing disappear.
3. Introduce the UIKit layer-animation Adapter and remove UIKit marquee frame delivery.
4. Update styled SwiftUI input synchronization and verify it uses the same UIKit implementation.
5. Replace native SwiftUI display-link publication with transition-driven animation.
6. Run package, UIKit, SwiftUI, UI, accessibility, RTL, and lifecycle regression suites.
7. Run the Release physical-device performance fixture and record the gate evidence before publication.

## Compatibility

The deployment target remains iOS 15. No public declaration changes, source migrations, or new caller obligations are introduced. The internal implementation may replace `_ITextMarqueeEngine` and its display-link ownership as long as existing testable behavior remains unchanged.
