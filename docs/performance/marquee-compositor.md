# Marquee Compositor Performance

## Gate

- Package commit under test: `c423b79e0deb353d513449a124bbdbfc8f7eaca9`
- Test date: 2026-08-13
- Device: iPhone SE (3rd generation), `iPhone14,6`
- Device UDID: `00008110-0001443A0147801E`
- OS: iOS 26.5.2 (23F84)
- Xcode: 26.6 (17F113)
- Build: Release, arm64, `ENABLE_TESTABILITY=YES`
- Signing: automatic signing with command-line team override `R88LA2DLDJ`; no
  project signing setting was changed

The release gate passes. UIKit marquee travel is owned by one Core Animation
translation on fixed copy geometry. Native SwiftUI marquee travel publishes
only discrete animation transitions. Styled SwiftUI marquee content reuses the
UIKit compositor path.

## 0.3.1 Playback Regression

The playback-control fixes were validated at package commit
`2d42609bc27a9058824f269233fe69d222a5f870`. A real simulator UI regression
scrolls the SwiftUI catalog, captures the visible plain Marquee, and exercises
the complete sequence:

1. playing produces different frames;
2. Pause produces identical frames;
3. Resume produces different frames again;
4. Stop produces identical frames at the reset presentation;
5. Start reapplies the initial delay and then produces different frames.

The complete Example scheme passed serially with this regression. The same
Release candidate then ran
`testSixMarqueesDoNotRebuildDuringSteadyTravel()` for 10.140 seconds on the
iPhone SE and passed with zero measurement, layout, drawing, and glyph-path
rebuilds after warm-up. Its retained result is
`/private/tmp/ITextKit-Marquee-Steady-Device-2.xcresult`.

Physical-device UI Automation did not start: two attempts timed out while
enabling automation mode before the test method initialized. This is not
counted as passing physical-device playback-control evidence; the visible
five-state sequence above is simulator UI evidence.

## Fixture

The app was launched with `-ITextMarqueePerformance`. Its fixed-width `VStack`
eagerly mounts six overflowing rows without `LazyVStack`:

1. default plain SwiftUI text;
2. native `AttributedString` text;
3. linear-gradient fill plus linear-gradient stroke;
4. a second independent linear-gradient fill and stroke;
5. a 40-points-per-second configured marquee;
6. inherited right-to-left motion.

The app was allowed to warm for approximately 13 seconds before Time Profiler
recording began. The Animation Hitches recording followed the completed Time
Profiler run without relaunching the fixture.

## XCTest Evidence

The Release app-hosted suite ran on the physical device with:

```bash
xcodebuild -quiet -project Example/ITextKitExample.xcodeproj \
  -scheme ITextKitExample -configuration Release \
  ENABLE_TESTABILITY=YES DEVELOPMENT_TEAM=R88LA2DLDJ \
  CODE_SIGN_STYLE=Automatic \
  -destination 'platform=iOS,id=00008110-0001443A0147801E' \
  -parallel-testing-enabled NO \
  -resultBundlePath /private/tmp/ITextKit-Marquee-Device.xcresult \
  -only-testing:ITextKitExamplePerformanceTests test-without-building
```

All six tests passed. The six-marquee steady-state test ran for 10.126 seconds
after warm-up and reported:

| Metric | Result | Required |
| --- | ---: | ---: |
| Marquee measurement rebuilds | 0 | 0 |
| Marquee layout rebuilds | 0 | 0 |
| Marquee drawing rebuilds | 0 | 0 |
| Marquee glyph-path rebuilds | 0 | 0 |

The same result bundle also recorded these supporting measurements:

| Metric | Result | Limit |
| --- | ---: | ---: |
| Cold layout and drawing p95 | 0.581875 ms | 4 ms |
| Warm unchanged redraw p95 | 0.001083 ms | 1 ms |
| Styled 20-row scroll p95 | 0.057667 ms | — |
| Native 20-row scroll p95 | 0.073583 ms | — |
| Styled minus native p95 | -0.015917 ms | 1 ms |
| Glyph cache peak entries | 32 | 2,048 |
| Glyph cache peak estimated bytes | 2,050 | 8,388,608 |

Retained result bundle:

- `/private/tmp/ITextKit-Marquee-Device.xcresult`

## Instruments Evidence

The installed Release app was launched in the foreground with the fixture
argument and recorded twice while remaining untouched:

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

Time Profiler recorded for 30.870 seconds and captured 2,342 one-millisecond
running-thread samples. This is equivalent to 7.5865% of one CPU core across
the process. Exported stacks contained no ITextKit layout, drawing, marquee,
or glyph-path function frame.

Animation Hitches recorded for 30.766 seconds and reported:

- 0 animation hitches;
- 0 potential hangs above the template's 33 ms threshold;
- 59.7586 displayed surface swaps per second averaged over the 29 complete
  steady-state seconds;
- 58 minimum and 60 maximum swaps in those complete seconds.

The first capture-boundary second (32 swaps) and final partial second
(46 swaps over 766 ms) were excluded from the steady-state average.

Retained traces and exported evidence:

- `/private/tmp/marquee-time-profiler.trace`
- `/private/tmp/marquee-animation-hitches.trace`
- `/private/tmp/marquee-time-profile.xml`
- `/private/tmp/marquee-hitches.xml`
- `/private/tmp/marquee-potential-hangs.xml`
- `/private/tmp/marquee-surfaces-per-second.xml`

## Simulator Regression

Simulator results are diagnostic rather than release-performance evidence.
On iPhone 17 Pro simulator `CB8D5108-54ED-4BE1-B27F-A34164D98E72`, the Core,
UIKit, and SwiftUI package schemes passed serially. The complete Example scheme
also passed serially, including catalog UI tests, inherited RTL, viewport and
accessibility checks, both performance fixtures, and app-hosted performance
tests.

The simulator six-marquee 10-second counter test also reported zero
measurement, layout, drawing, and glyph-path rebuilds after warm-up.
