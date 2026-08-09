# ITextKit Example

This offline iOS application demonstrates both public API families from the same local `ITextKit` package product.

- **SwiftUI** uses `ITextRotator` and `ITextMarquee` with declarative `ITextPlaybackState`.
- **UIKit** uses `ITextRotatorView` and `ITextMarqueeView`, including `start()`, `pause()`, `resume()`, and `stop()`.

The rotator examples deliberately mix short and multiline messages so intrinsic height changes are visible.

## Generate and Run

The checked-in source and `project.yml` have no remote package dependency. Generate the project with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
cd Example
xcodegen generate
open ITextKitExample.xcodeproj
```

Select the `ITextKitExample` scheme and any iOS 15 or newer simulator.
