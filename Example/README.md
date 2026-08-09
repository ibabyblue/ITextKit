# ITextKit Example

This offline iOS application demonstrates both public API families from the same local `ITextKit` package product.

- **SwiftUI** shows plain `String` and rich `AttributedString` input. Rotator and marquee use declarative `ITextPlaybackState`; typewriter starts automatically.
- **UIKit** shows plain `String` and rich `NSAttributedString` input. Rotator and marquee include `start()`, `pause()`, `resume()`, and `stop()`; typewriter is an independent one-shot effect.

All rotator examples use short single-line messages. Rich examples still demonstrate font, color, bold, and underline attributes without wrapping.
The typewriter examples grow from an empty visual size, preserve rich attributes, and wrap when they reach the caller-provided maximum width.
Each framework tab includes a **Replay Typewriter** button that retriggers both typewriter examples without adding playback controls to the public Typewriter API.

## Generate and Run

The checked-in source and `project.yml` have no remote package dependency. Generate the project with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
cd Example
xcodegen generate
open ITextKitExample.xcodeproj
```

Select the `ITextKitExample` scheme and any iOS 15 or newer simulator.
