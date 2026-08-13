# ITextKit Marquee Compositor Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make UIKit and SwiftUI marquee motion smooth by caching text layout and drawing, moving prepared content through platform animation, and proving the result on an iPhone SE without changing the public interface.

**Architecture:** Keep one internal marquee state Module for overflow, timing, and playback semantics. A UIKit Adapter installs a repeating Core Animation translation on a fixed two-copy container; styled SwiftUI reuses it. Native SwiftUI keeps native `Text` but changes from display-link publication to discrete linear-animation transitions derived from the same logical timing state.

**Tech Stack:** Swift 5.10, UIKit, SwiftUI, QuartzCore, Combine, CoreText, XCTest/XCUITest, SwiftPM, XcodeGen, Instruments, iOS 15+

## Global Constraints

- The deployment target remains iOS 15.0.
- Do not change `ITextMarquee`, `ITextMarqueeView`, `ITextMarqueeConfiguration`, or `ITextPlaybackState` public declarations.
- Preserve plain, attributed, styled, linear-gradient fill, linear-gradient stroke, RTL, Dynamic Type, accessibility, Reduce Motion, and playback behavior.
- `start()` resets to semantic leading and reapplies the full initial delay.
- `pause()` and scene inactivity freeze exact progress; `resume()` and scene activation continue without a jump.
- `stop()` discards progress and returns to semantic leading.
- Native unstyled SwiftUI content remains native `Text(AttributedString)`; do not convert it to UIKit/CoreText.
- No per-frame text measurement, CoreText layout, drawing-plan rebuild, glyph rasterization, or SwiftUI observable publication is allowed in steady travel.
- Do not add dependencies, images, Metal, Canvas, unbounded caches, or public test instrumentation.
- Keep the example page capable of running all specimens eagerly; example laziness is not the fix.
- Physical-device performance evidence must come from a Release, arm64, app-hosted run on `Sjj iPhone SE` (`00008110-0001443A0147801E`).
- Use `apply_patch` for edits and regenerate `Example/ITextKitExample.xcodeproj` with XcodeGen after adding Example sources.
- Run simulator UI tests serially with `-parallel-testing-enabled NO`.

## File Map

Create:

- `Sources/ITextKit/Internal/ITextMarqueeLayerAnimator.swift`: Core Animation install, pause, resume, stop, and canonical layer-timing reset.
- `Tests/ITextKitUIKitTests/ITextMarqueeViewTests.swift`: fixed-geometry, animation, playback, RTL, accessibility, and steady-state invalidation tests.
- `Tests/ITextKitSwiftUITests/ITextMarqueeAnimationTests.swift`: native SwiftUI discrete-transition and styled bridge regressions.
- `Example/ITextKitExample/MarqueePerformanceView.swift`: isolated eager six-marquee fixture.
- `docs/performance/marquee-compositor.md`: retained simulator/device commands and measured results.

Modify:

- `Sources/ITextKit/Internal/ITextMarqueeEngine.swift`: change from frame-emitting state to event-synchronized logical timing and motion plans.
- `Sources/ITextKit/UIKit/ITextStyledLabel.swift`: suppress equal-value invalidation and expose internal generation counters.
- `Sources/ITextKit/Internal/StyledText/ITextDrawingLayer.swift`: count actual drawing generations internally.
- `Sources/ITextKit/UIKit/ITextMarqueeView.swift`: cache geometry, own a fixed motion container, and remove marquee display-link layout.
- `Sources/ITextKit/SwiftUI/ITextMarquee.swift`: replace per-frame `@Published snapshot` with discrete transition state.
- `Sources/ITextKit/SwiftUI/ITextStyledEffectsRepresentable.swift`: compare resolved inputs before UIKit assignment.
- `Tests/ITextKitCoreTests/ITextMarqueeEngineTests.swift`: test monotonic event synchronization and motion plans.
- `Tests/ITextKitUIKitTests/ITextStyledLabelTests.swift`: verify equal assignments do not invalidate.
- `Tests/ITextKitSwiftUITests/ITextKitSwiftUIAPITests.swift`: update hosted styled marquee expectations without direct frame advancement.
- `Example/ITextKitExample/ITextKitExampleApp.swift`: route `-ITextMarqueePerformance` to the new fixture.
- `Example/ITextKitExamplePerformanceTests/ITextKitExamplePerformanceTests.swift`: record marquee layout, drawing, and path rebuild counters.
- `Example/ITextKitExampleUITests/PerformanceFixtureUITests.swift`: assert the new fixture mounts six specimens.
- `Example/ITextKitExample.xcodeproj/project.pbxproj`: regenerate Example source membership.

---

### Task 1: Styled Text Equal-Assignment Invalidation

**Files:**
- Modify: `Sources/ITextKit/UIKit/ITextStyledLabel.swift:15-115`
- Modify: `Sources/ITextKit/Internal/StyledText/ITextDrawingLayer.swift:4-35`
- Modify: `Tests/ITextKitUIKitTests/ITextStyledLabelTests.swift`

**Interfaces:**
- Produces internally: `ITextStyledLabel._drawingGeneration: UInt64`.
- Preserves: existing `_layoutGeneration` and all public `UILabel` behavior.
- Consumed by: Tasks 3, 4, and 6 performance assertions.

- [ ] **Step 1: Write the failing equal-assignment test**

```swift
func testEqualAssignmentsDoNotInvalidateLayoutOrDrawing() {
    let label = ITextStyledLabel(
        frame: CGRect(x: 0, y: 0, width: 260, height: 44)
    )
    label.text = "Gradient marquee"
    label.font = .systemFont(ofSize: 20, weight: .bold)
    label.numberOfLines = 1
    label.lineBreakMode = .byClipping
    label.textStyle = .init(
        fill: .linearGradient(.init(colors: [.systemPink, .systemOrange])),
        stroke: .init(
            paint: .linearGradient(.init(colors: [.white, .black])),
            width: 1
        )
    )
    label.layoutIfNeeded()
    label.layer.displayIfNeeded()
    let layoutGeneration = label._layoutGeneration
    let drawingGeneration = label._drawingGeneration

    label.text = label.text
    label.font = label.font
    label.numberOfLines = label.numberOfLines
    label.lineBreakMode = label.lineBreakMode
    label.textAlignment = label.textAlignment
    label.textStyle = label.textStyle
    label.layoutIfNeeded()
    label.layer.displayIfNeeded()

    XCTAssertEqual(label._layoutGeneration, layoutGeneration)
    XCTAssertEqual(label._drawingGeneration, drawingGeneration)
}
```

- [ ] **Step 2: Run the test and verify RED**

```bash
xcodebuild -quiet -project Example/ITextKitExample.xcodeproj \
  -scheme ITextKitUIKitTests \
  -destination 'platform=iOS Simulator,id=CB8D5108-54ED-4BE1-B27F-A34164D98E72' \
  -only-testing:ITextKitUIKitTests/ITextStyledLabelTests/testEqualAssignmentsDoNotInvalidateLayoutOrDrawing \
  test
```

Expected: compile failure because `_drawingGeneration` does not exist; after adding only the counter, the assertion fails because equal assignments still invalidate.

- [ ] **Step 3: Add the drawing counter and equality guards**

In `_ITextDrawingLayer`:

```swift
private(set) var drawingGeneration: UInt64 = 0

override func draw(in context: CGContext) {
    drawingGeneration &+= 1
    plan?.draw(in: context)
}
```

Expose it internally from `ITextStyledLabel`:

```swift
var _drawingGeneration: UInt64 { drawingLayer.drawingGeneration }
```

Guard every invalidating override before calling `invalidateStyledLayout()` or `invalidateStyledPaint()`. Use value equality for Swift values and `isEqual` for attributed strings. The required pattern is:

```swift
public override var lineBreakMode: NSLineBreakMode {
    didSet {
        guard lineBreakMode != oldValue else { return }
        invalidateStyledLayout()
    }
}

public override var attributedText: NSAttributedString? {
    didSet {
        guard !(attributedText?.isEqual(to: oldValue) ?? oldValue == nil) else {
            return
        }
        invalidateStyledLayout()
    }
}
```

Apply the same rule to `textStyle`, `_gradientReferenceAttributedText`, `text`, `font`, `textColor`, `numberOfLines`, `textAlignment`, `baselineAdjustment`, `adjustsFontSizeToFitWidth`, `minimumScaleFactor`, `allowsDefaultTighteningForTruncation`, `preferredMaxLayoutWidth`, `shadowColor`, `shadowOffset`, and `semanticContentAttribute`.

- [ ] **Step 4: Run the complete styled-label suite**

Run the Task 1 command without the method suffix. Expected: all `ITextStyledLabelTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/ITextKit/UIKit/ITextStyledLabel.swift Sources/ITextKit/Internal/StyledText/ITextDrawingLayer.swift Tests/ITextKitUIKitTests/ITextStyledLabelTests.swift
git commit -m "perf: ignore equal styled label updates"
```

---

### Task 2: Event-Synchronized Marquee Motion Module

**Files:**
- Modify: `Sources/ITextKit/Internal/ITextMarqueeEngine.swift`
- Modify: `Tests/ITextKitCoreTests/ITextMarqueeEngineTests.swift`

**Interfaces:**
- Produces: `_ITextMarqueeMotionPlan` with `offset`, `cycleDistance`, `speed`, and `delay`.
- Produces: `_ITextMarqueeEngine.motionPlan: _ITextMarqueeMotionPlan?`.
- Produces: initializer clock seam `now: @escaping () -> CFTimeInterval = CACurrentMediaTime`.
- Preserves: `snapshot`, configuration normalization, overflow, and caller playback state.
- Consumed by: UIKit and SwiftUI Adapters in Tasks 3-5.

- [ ] **Step 1: Replace frame-advance tests with failing clock-driven tests**

```swift
private final class TestClock {
    var time: CFTimeInterval = 0
    func now() -> CFTimeInterval { time }
}

func testMotionPlanConsumesDelayAndFreezesExactOffset() throws {
    let clock = TestClock()
    let engine = makeEngine(speed: 20, spacing: 10, delay: 1, now: clock.now)
    engine.updateMetrics(contentWidth: 80, viewportWidth: 40)
    engine.setEnvironmentActive(true)
    XCTAssertEqual(try XCTUnwrap(engine.motionPlan).delay, 1)

    clock.time = 1.5
    engine.setPlaybackState(.paused)
    XCTAssertEqual(engine.snapshot.offset, 10, accuracy: 0.000_001)

    clock.time = 50
    engine.setPlaybackState(.playing)
    XCTAssertEqual(try XCTUnwrap(engine.motionPlan).offset, 10, accuracy: 0.000_001)
    XCTAssertEqual(try XCTUnwrap(engine.motionPlan).delay, 0)
}

func testSceneFreezeDuringInitialDelayPreservesRemainingDelay() throws {
    let clock = TestClock()
    let engine = makeEngine(speed: 20, spacing: 10, delay: 1, now: clock.now)
    engine.updateMetrics(contentWidth: 80, viewportWidth: 40)
    engine.setEnvironmentActive(true)
    clock.time = 0.25
    engine.setEnvironmentActive(false)
    clock.time = 20
    engine.setEnvironmentActive(true)
    XCTAssertEqual(try XCTUnwrap(engine.motionPlan).delay, 0.75, accuracy: 0.000_001)
}
```

Retain tests for stop/start reset, meaningful geometry/configuration restart, fitting text, zero speed, Reduce Motion, and seamless modulo wrapping. Remove direct `advance(by:)` expectations because renderers will no longer call it per frame.

- [ ] **Step 2: Run the engine suite and verify RED**

```bash
xcodebuild -quiet -project Example/ITextKitExample.xcodeproj \
  -scheme ITextKitCoreTests \
  -destination 'platform=iOS Simulator,id=CB8D5108-54ED-4BE1-B27F-A34164D98E72' \
  -only-testing:ITextKitCoreTests/ITextMarqueeEngineTests test
```

Expected: compile failure for the injected clock and `motionPlan`.

- [ ] **Step 3: Implement monotonic event synchronization**

Add:

```swift
struct _ITextMarqueeMotionPlan: Equatable {
    let offset: CGFloat
    let cycleDistance: CGFloat
    let speed: CGFloat
    let delay: TimeInterval

    var remainingCycleDuration: TimeInterval {
        TimeInterval((cycleDistance - offset) / speed)
    }
}
```

Store `now`, `lastRunningTimestamp`, `offset`, and `remainingInitialDelay`. Before playback, environment, motion permission, metrics, configuration, or restart changes, synchronize elapsed time exactly once:

```swift
private func synchronizeProgress() {
    guard shouldAdvance, let lastRunningTimestamp else { return }
    let timestamp = now()
    let elapsed = max(timestamp - lastRunningTimestamp, 0)
    self.lastRunningTimestamp = timestamp
    consume(elapsed)
}
```

`consume(_:)` first reduces `remainingInitialDelay`, then advances `offset` modulo `cycleDistance`. State transitions set or clear `lastRunningTimestamp` without emitting display-frame snapshots. `motionPlan` returns `nil` unless `shouldAdvance`; otherwise it returns the synchronized frozen offset, remaining delay, cycle distance, and speed.

- [ ] **Step 4: Run the engine suite**

Expected: all clock-driven lifecycle, delay, playback, configuration, and overflow tests pass without sleeping.

- [ ] **Step 5: Commit**

```bash
git add Sources/ITextKit/Internal/ITextMarqueeEngine.swift Tests/ITextKitCoreTests/ITextMarqueeEngineTests.swift
git commit -m "refactor: make marquee timing event driven"
```

---

### Task 3: Fixed UIKit Marquee Geometry

**Files:**
- Modify: `Sources/ITextKit/UIKit/ITextMarqueeView.swift`
- Create: `Tests/ITextKitUIKitTests/ITextMarqueeViewTests.swift`

**Interfaces:**
- Produces internally: `ITextMarqueeView._measurementGeneration: UInt64`.
- Produces internally: `ITextMarqueeView._movingLabels: [ITextStyledLabel]` for test inspection.
- Consumes: `_ITextMarqueeEngine.motionPlan` from Task 2.
- Consumed by: layer animation in Task 4.

- [ ] **Step 1: Write failing fixed-geometry tests**

Create a window-hosted 180-point viewport and assert:

```swift
func testSteadyMotionDoesNotMeasureOrRelayoutStyledCopies() {
    let marquee = makeHostedMarquee(styled: true, direction: .leftToRight)
    let measurement = marquee._measurementGeneration
    let layoutGenerations = marquee._movingLabels.map(\._layoutGeneration)
    let drawingGenerations = marquee._movingLabels.map(\._drawingGeneration)

    RunLoop.main.run(until: Date().addingTimeInterval(0.25))

    XCTAssertEqual(marquee._measurementGeneration, measurement)
    XCTAssertEqual(marquee._movingLabels.map(\._layoutGeneration), layoutGenerations)
    XCTAssertEqual(marquee._movingLabels.map(\._drawingGeneration), drawingGenerations)
}
```

Also assert two moving labels have fixed widths equal to cached `contentWidth`, spacing is exact, the fitting path hides the repeated copy, and one accessibility element exposes the full string.
Assert a fill-color-only style change preserves motion geometry and offset, while an outward stroke-width change rebuilds geometry and restarts from leading.

- [ ] **Step 2: Run the new suite and verify RED**

```bash
xcodebuild -quiet -project Example/ITextKitExample.xcodeproj \
  -scheme ITextKitUIKitTests \
  -destination 'platform=iOS Simulator,id=CB8D5108-54ED-4BE1-B27F-A34164D98E72' \
  -only-testing:ITextKitUIKitTests/ITextMarqueeViewTests test
```

Expected: compile failure for the internal inspection seam; after adding only counters, measurement/layout/drawing generations increase during travel.

- [ ] **Step 3: Introduce one fixed motion container and cached geometry**

Add `motionContainerView`, move both private labels into it, and replace `measuredTextSize` with a cached value rebuilt by `prepareGeometryIfNeeded()`. A `geometryIsDirty` flag becomes true only for content, font, attributed input, stroke width, bounds size, spacing, Dynamic Type, display scale, or layout-direction changes.

During preparation, keep the container fixed to the viewport and place the
copies once for the resolved physical direction:

```swift
let distance = contentWidth + configuration.resolved.spacing
motionContainerView.frame = bounds
let primaryX = direction == .rightToLeft ? bounds.width - contentWidth : 0
let repeatedX = direction == .rightToLeft
    ? primaryX - distance
    : primaryX + distance
primaryLabel.frame = CGRect(
    x: primaryX, y: 0, width: contentWidth, height: bounds.height
)
repeatedLabel.frame = CGRect(
    x: repeatedX, y: 0, width: contentWidth, height: bounds.height
)
```

Assign `lineBreakMode` only when switching between static and moving presentation. Increment `_measurementGeneration` only when actual measurement occurs. Remove `setNeedsLayout()` from offset/snapshot delivery; the steady-state path must not set label frames.

- [ ] **Step 4: Run UIKit marquee and styled-label suites**

Run Task 3's command plus `-only-testing:ITextKitUIKitTests/ITextStyledLabelTests`. Expected: fixed geometry and equal-invalidation tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/ITextKit/UIKit/ITextMarqueeView.swift Tests/ITextKitUIKitTests/ITextMarqueeViewTests.swift
git commit -m "refactor: cache UIKit marquee geometry"
```

---

### Task 4: UIKit Core Animation Travel

**Files:**
- Create: `Sources/ITextKit/Internal/ITextMarqueeLayerAnimator.swift`
- Modify: `Sources/ITextKit/UIKit/ITextMarqueeView.swift`
- Modify: `Tests/ITextKitUIKitTests/ITextMarqueeViewTests.swift`

**Interfaces:**
- Produces: `_ITextMarqueeLayerAnimator.install(on:plan:direction:)`, `pause()`, `resume()`, and `stop()`.
- Produces internally: `ITextMarqueeView._hasActiveTravelAnimation: Bool`.
- Removes: marquee ownership of `_ITextDisplayLinkDriver` from UIKit.

- [ ] **Step 1: Add failing animation and playback tests**

Assert overflowing motion installs key `ITextKit.marquee.travel`, uses `.linear`, has `repeatCount == .infinity`, and computes `duration == cycleDistance / speed`. Assert fitting, zero-speed, stopped, and Reduce Motion paths install no animation. Assert LTR `toValue` is negative and inherited RTL is positive.

For pause/resume:

```swift
marquee.pause()
let frozenOffset = marquee._motionLayerTimeOffset
RunLoop.main.run(until: Date().addingTimeInterval(0.1))
XCTAssertEqual(marquee._motionLayerTimeOffset, frozenOffset)
marquee.resume()
XCTAssertEqual(marquee._motionLayerSpeed, 1)
```

Also assert scene inactivity freezes layer time without changing `playbackState`, and activation resumes only if caller state is `.playing`.
Assert removing the marquee from its window removes active animation resources and reattachment reconstructs the retained logical phase without exposing a duplicate accessibility element.

- [ ] **Step 2: Run the UIKit marquee suite and verify RED**

Use Task 3's test command. Expected: no Core Animation travel key or layer timing inspection exists.

- [ ] **Step 3: Implement the layer Adapter**

Install this animation with implicit actions disabled:

```swift
let animation = CABasicAnimation(keyPath: "transform.translation.x")
animation.fromValue = direction == .leftToRight ? -plan.offset : plan.offset
animation.toValue = direction == .leftToRight
    ? -plan.cycleDistance
    : plan.cycleDistance
animation.duration = plan.remainingCycleDuration
animation.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) + plan.delay
animation.timingFunction = CAMediaTimingFunction(name: .linear)
animation.fillMode = .backwards
animation.repeatCount = plan.offset == 0 ? .infinity : 0
animation.isRemovedOnCompletion = false
```

When reconstructing from a nonzero offset, finish the partial cycle once; its delegate installs the full zero-to-distance repeating cycle. Use a generation token so obsolete completion cannot restart after stop, restart, or geometry change.

Pause and resume the motion layer with the standard local-time algorithm:

```swift
let pausedTime = layer.convertTime(CACurrentMediaTime(), from: nil)
layer.speed = 0
layer.timeOffset = pausedTime

let frozenTime = layer.timeOffset
layer.speed = 1
layer.timeOffset = 0
layer.beginTime = 0
let timeSincePause = layer.convertTime(CACurrentMediaTime(), from: nil) - frozenTime
layer.beginTime = timeSincePause
```

`stop()` removes the keyed animation and restores `speed = 1`, `timeOffset = 0`, `beginTime = 0`, and identity transform. `ITextMarqueeView` calls the Adapter only for discrete geometry, playback, Reduce Motion, direction, window, and scene changes.

- [ ] **Step 4: Prove steady travel does no layout or drawing**

Run `ITextMarqueeViewTests` for at least 0.5 seconds with two styled copies. Expected: active presentation movement, unchanged measurement/layout/drawing generations, and no UIKit marquee display link.

- [ ] **Step 5: Run all UIKit suites**

```bash
xcodebuild -quiet -project Example/ITextKitExample.xcodeproj \
  -scheme ITextKitUIKitTests \
  -destination 'platform=iOS Simulator,id=CB8D5108-54ED-4BE1-B27F-A34164D98E72' test
```

- [ ] **Step 6: Commit**

```bash
git add Sources/ITextKit/Internal/ITextMarqueeLayerAnimator.swift Sources/ITextKit/UIKit/ITextMarqueeView.swift Tests/ITextKitUIKitTests/ITextMarqueeViewTests.swift
git commit -m "perf: move UIKit marquee with Core Animation"
```

---

### Task 5: SwiftUI Discrete Animation Adapter

**Files:**
- Modify: `Sources/ITextKit/SwiftUI/ITextMarquee.swift`
- Modify: `Sources/ITextKit/SwiftUI/ITextStyledEffectsRepresentable.swift`
- Create: `Tests/ITextKitSwiftUITests/ITextMarqueeAnimationTests.swift`
- Modify: `Tests/ITextKitSwiftUITests/ITextKitSwiftUIAPITests.swift`

**Interfaces:**
- Produces internally: `_ITextSwiftUIMarqueeTransition` with `targetOffset`, `duration`, `delay`, `repeats`, and `generation`.
- Produces internally: `_ITextMarqueeObservable._publicationGeneration: UInt64`.
- Consumes: `_ITextMarqueeEngine.motionPlan` and optimized `ITextMarqueeView`.
- Removes: `_ITextDisplayLinkDriver` ownership from native SwiftUI marquee.

- [ ] **Step 1: Write failing discrete-publication tests**

Make `_ITextMarqueeObservable` internal and inject the Task 2 clock plus an internal sleeper closure. Test that starting overflowing content publishes one repeating transition, 0.25 seconds of logical travel produces no additional publication, pause publishes one static transition at the computed offset, and resume publishes one remaining-cycle transition.

```swift
let count = model._publicationGeneration
clock.time += 0.25
XCTAssertEqual(model._publicationGeneration, count)
model.setPlaybackState(.paused)
XCTAssertEqual(model.transition.targetOffset, 10, accuracy: 0.000_001)
XCTAssertEqual(model._publicationGeneration, count + 1)
```

Update the existing hosted styled test to assert `_hasActiveTravelAnimation` after `marquee.resume()` instead of reaching into the engine and calling `advance(by:)`.

- [ ] **Step 2: Run SwiftUI tests and verify RED**

```bash
xcodebuild -quiet -project Example/ITextKitExample.xcodeproj \
  -scheme ITextKitSwiftUITests \
  -destination 'platform=iOS Simulator,id=CB8D5108-54ED-4BE1-B27F-A34164D98E72' \
  -only-testing:ITextKitSwiftUITests/ITextMarqueeAnimationTests \
  -only-testing:ITextKitSwiftUITests/ITextKitSwiftUIAPITests/testStyledMarqueeUsesProposedViewportAndOverflows \
  test
```

Expected: transition/publication seams do not exist and the old test still depends on direct frame advancement.

- [ ] **Step 3: Implement native SwiftUI transition rendering**

Define:

```swift
struct _ITextSwiftUIMarqueeTransition: Equatable {
    let targetOffset: CGFloat
    let duration: TimeInterval
    let delay: TimeInterval
    let repeats: Bool
    let generation: UInt64

    var animation: Animation? {
        guard duration > 0 else { return nil }
        let base = Animation.linear(duration: duration).delay(delay)
        return repeats ? base.repeatForever(autoreverses: false) : base
    }
}
```

Replace `snapshot.offset` in the view with `transition.targetOffset` and attach `transition.animation` to `transition.generation`. Static transitions use a transaction with animations disabled. On resume from a partial offset, publish a one-shot transition to `cycleDistance`; schedule exactly one cancellable task for its delay plus duration; at the seam publish offset zero without animation and then a full repeating transition. Increment a task generation on every restart, stop, pause, geometry, direction, or lifecycle change and ignore stale completions.

The observable may publish on discrete input/state transitions only. It must not own a display link or schedule a frame-rate timer.

- [ ] **Step 4: Guard styled representable updates**

In `updateUIView`, compare attributed text, configuration, font, scaling flag, resolved style, and playback state before assignment. Do not assign `font` or `textStyle` merely because another native SwiftUI marquee advanced.

- [ ] **Step 5: Run all SwiftUI and UIKit marquee suites**

```bash
xcodebuild -quiet -project Example/ITextKitExample.xcodeproj \
  -scheme ITextKitSwiftUITests \
  -destination 'platform=iOS Simulator,id=CB8D5108-54ED-4BE1-B27F-A34164D98E72' test
xcodebuild -quiet -project Example/ITextKitExample.xcodeproj \
  -scheme ITextKitUIKitTests \
  -destination 'platform=iOS Simulator,id=CB8D5108-54ED-4BE1-B27F-A34164D98E72' \
  -only-testing:ITextKitUIKitTests/ITextMarqueeViewTests test
```

- [ ] **Step 6: Commit**

```bash
git add Sources/ITextKit/SwiftUI/ITextMarquee.swift Sources/ITextKit/SwiftUI/ITextStyledEffectsRepresentable.swift Tests/ITextKitSwiftUITests/ITextMarqueeAnimationTests.swift Tests/ITextKitSwiftUITests/ITextKitSwiftUIAPITests.swift
git commit -m "perf: remove SwiftUI marquee frame publication"
```

---

### Task 6: Eager Performance Fixture and Regression Gate

**Files:**
- Create: `Example/ITextKitExample/MarqueePerformanceView.swift`
- Modify: `Example/ITextKitExample/ITextKitExampleApp.swift`
- Modify: `Example/ITextKitExamplePerformanceTests/ITextKitExamplePerformanceTests.swift`
- Modify: `Example/ITextKitExampleUITests/PerformanceFixtureUITests.swift`
- Modify: `Example/ITextKitExample.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: launch argument `-ITextMarqueePerformance`.
- Produces: accessibility identifier `Marquee performance fixture`.
- Produces: six eagerly mounted overflowing rows including native, attributed, styled gradient fill/stroke, configured, and RTL content.

- [ ] **Step 1: Write the failing fixture UI test**

```swift
func testMarqueePerformanceLaunchArgumentShowsSixEagerRows() {
    let app = XCUIApplication()
    app.launchArguments = ["-ITextMarqueePerformance"]
    app.launch()
    XCTAssertTrue(
        app.otherElements["Marquee performance fixture"]
            .waitForExistence(timeout: 2)
    )
    XCTAssertEqual(
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH 'Marquee row '")
        ).count,
        6
    )
}
```

- [ ] **Step 2: Run the fixture test and verify RED**

```bash
cd Example
xcodegen generate
cd ..
xcodebuild -quiet -project Example/ITextKitExample.xcodeproj \
  -scheme ITextKitExample \
  -destination 'platform=iOS Simulator,id=CB8D5108-54ED-4BE1-B27F-A34164D98E72' \
  -parallel-testing-enabled NO \
  -only-testing:ITextKitExampleUITests/PerformanceFixtureUITests/testMarqueePerformanceLaunchArgumentShowsSixEagerRows \
  test
```

Expected: fixture identifier does not exist.

- [ ] **Step 3: Implement the isolated fixture**

Use one fixed-width `VStack` with six always-mounted `ITextMarquee` rows. Include one `AttributedString`, two styled rows using linear-gradient fill plus linear-gradient stroke, one 40-points-per-second configuration, one RTL row, and one default plain row. Give every row an explicit accessibility label `Marquee row 0` through `Marquee row 5`; do not wrap them in `LazyVStack`.

Route it before the normal catalog:

```swift
if ProcessInfo.processInfo.arguments.contains("-ITextMarqueePerformance") {
    MarqueePerformanceView()
} else if ProcessInfo.processInfo.arguments.contains("-ITextStyledPerformance") {
    StyledTextPerformanceView()
} else {
    ExampleRootView()
}
```

Regenerate with `xcodegen generate --spec Example/project.yml`.

- [ ] **Step 4: Add app-hosted steady-state counter assertions**

Add `testSixMarqueesDoNotRebuildDuringSteadyTravel`. Warm six UIKit marquee views, record each private label's layout and drawing generations plus shared glyph-cache count/cost and each marquee measurement generation, run the main loop for ten seconds, and assert every value is unchanged. Keep the existing shimmer assertions separate.

- [ ] **Step 5: Run simulator performance and fixture suites**

```bash
xcodebuild -quiet -project Example/ITextKitExample.xcodeproj \
  -scheme ITextKitExample \
  -destination 'platform=iOS Simulator,id=CB8D5108-54ED-4BE1-B27F-A34164D98E72' \
  -parallel-testing-enabled NO \
  -only-testing:ITextKitExamplePerformanceTests \
  -only-testing:ITextKitExampleUITests/PerformanceFixtureUITests test
```

Expected: zero steady-state measurement, layout, drawing, and glyph-path rebuilds.

- [ ] **Step 6: Commit**

```bash
git add Example/ITextKitExample/MarqueePerformanceView.swift Example/ITextKitExample/ITextKitExampleApp.swift Example/ITextKitExamplePerformanceTests/ITextKitExamplePerformanceTests.swift Example/ITextKitExampleUITests/PerformanceFixtureUITests.swift Example/ITextKitExample.xcodeproj/project.pbxproj
git commit -m "test: add marquee performance fixture"
```

---

### Task 7: Full Regression, Device Evidence, and Documentation

**Files:**
- Create: `docs/performance/marquee-compositor.md`
- Modify only if behavior wording changed: `Sources/ITextKit/Documentation.docc/TextMarquee.md`

**Interfaces:**
- Consumes: completed implementation and `-ITextMarqueePerformance` fixture.
- Produces: reproducible simulator and iPhone SE evidence with exact result-bundle and trace paths.

- [ ] **Step 1: Run all package suites serially**

```bash
for scheme in ITextKitCoreTests ITextKitUIKitTests ITextKitSwiftUITests; do
  xcodebuild -quiet -project Example/ITextKitExample.xcodeproj \
    -scheme "$scheme" \
    -destination 'platform=iOS Simulator,id=CB8D5108-54ED-4BE1-B27F-A34164D98E72' \
    -parallel-testing-enabled NO test || exit 1
done
```

Expected: every Core, UIKit, and SwiftUI test passes.

- [ ] **Step 2: Run the full Example UI suite serially**

```bash
xcodebuild -quiet -project Example/ITextKitExample.xcodeproj \
  -scheme ITextKitExample \
  -destination 'platform=iOS Simulator,id=CB8D5108-54ED-4BE1-B27F-A34164D98E72' \
  -parallel-testing-enabled NO test
```

Expected: catalog, Marquee, RTL, accessibility, viewport, and both performance-fixture UI suites pass.

- [ ] **Step 3: Build and run Release app-hosted tests on iPhone SE**

```bash
xcodebuild -quiet -project Example/ITextKitExample.xcodeproj \
  -scheme ITextKitExample -configuration Release ENABLE_TESTABILITY=YES \
  -destination 'platform=iOS,id=00008110-0001443A0147801E' \
  -parallel-testing-enabled NO \
  -resultBundlePath /private/tmp/ITextKit-Marquee-Device.xcresult \
  -only-testing:ITextKitExamplePerformanceTests test
```

Expected: the six-marquee ten-second counter test reports zero measurement, layout, drawing-plan, drawing-layer, and glyph-path rebuilds after warm-up.

- [ ] **Step 4: Record Time Profiler and Animation Hitches**

Install and launch the Release app with `-ITextMarqueePerformance`, then attach two separate 30-second recordings on `Sjj iPhone SE`:

```bash
xcrun xctrace record --template 'Time Profiler' \
  --device 00008110-0001443A0147801E \
  --attach ITextKitExample --time-limit 30s \
  --output /private/tmp/marquee-time-profiler.trace
xcrun xctrace record --template 'Animation Hitches' \
  --device 00008110-0001443A0147801E \
  --attach ITextKitExample --time-limit 30s \
  --output /private/tmp/marquee-animation-hitches.trace
```

Export the relevant tables with `xcrun xctrace export --input <trace> --toc` followed by the table XPath shown by that trace. Verify zero steady-state hitches, 59-60 surface swaps per complete second, no sustained ITextKit layout/drawing stack, and sampling equivalent at or below 10% of one CPU core.

- [ ] **Step 5: Write the retained performance report**

Record commit, date, device model/UDID, OS/build, Release flags, fixture composition, warm-up, duration, counter results, CPU sample ratio, hitch count, surface swaps, trace paths, and result-bundle path in `docs/performance/marquee-compositor.md`. Clearly label simulator results diagnostic and device results release evidence.

- [ ] **Step 6: Run documentation build and inspect the final diff**

```bash
xcodebuild -quiet docbuild -scheme ITextKit \
  -destination 'generic/platform=iOS Simulator'
git diff --check
git status --short
```

Expected: DocC builds, `git diff --check` is empty, and only intended documentation/evidence files remain uncommitted.

- [ ] **Step 7: Commit evidence**

```bash
git add docs/performance/marquee-compositor.md
git add Sources/ITextKit/Documentation.docc/TextMarquee.md  # only when wording changed
git commit -m "docs: record marquee performance gate"
```

Do not stage `TextMarquee.md` if its behavior wording required no change. Do not publish or tag a release unless the user separately requests it.
