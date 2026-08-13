# ITextKit Example API Catalog

This offline application is a copyable teaching catalog for the public `ITextKit` product. Its two native tabs keep SwiftUI and UIKit APIs separate. Each tab contains six destinations:

- Styled Text / Styled Label
- Rotator / Rotator View
- Marquee / Marquee View
- Typewriter / Typewriter View
- Shimmer / Shimmer Label
- Accessibility & Environment

Every section places a live result beside a complete source snippet and a Copy action. The pages cover plain, attributed, and styled input; playback where the API supports it; intrinsic and multiline layout; semantic RTL; Dynamic Type; Reduce Motion; and accessibility ownership.

Styled examples include solid and linear-gradient fill, solid and linear-gradient outline, and combined fill + outline + shimmer. Stroke `width` is the visible outward thickness in real points: `2` means a 2-point outline outside the glyph and does not squeeze the fill.

SwiftUI styled content intentionally uses `ITextStyledText` with `UIFont` or `NSAttributedString`; it does not pretend to inspect an arbitrary native `Text` or `Font`. UIKit styled content uses `ITextStyledLabel` and retains normal UILabel intrinsic sizing and Auto Layout behavior.

## Generate and Run

The checked-in source and `project.yml` have no remote package dependency. Generate the project with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
cd Example
xcodegen generate
open ITextKitExample.xcodeproj
```

Select the `ITextKitExample` scheme and any iOS 15 or newer simulator. The project resolves the package from `..`; generation and normal use require no network or remote dependency.

## Maintainer Fixtures

Launch with `-ITextStyledPerformance` to show the hidden 20-row styled-text fixture used by app-hosted performance tests. This argument is not part of the consumer-facing catalog.
