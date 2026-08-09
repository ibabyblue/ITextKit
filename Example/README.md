# ITextKit Example

This offline iOS application demonstrates both public API families from the same local `ITextKit` package product.

- **SwiftUI** shows plain `String` and rich `AttributedString` input with declarative `ITextPlaybackState`.
- **UIKit** shows plain `String` and rich `NSAttributedString` input, including `start()`, `pause()`, `resume()`, and `stop()`.

All rotator examples use short single-line messages. Rich examples still demonstrate font, color, bold, and underline attributes without wrapping.

## Generate and Run

The checked-in source and `project.yml` have no remote package dependency. Generate the project with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
cd Example
xcodegen generate
open ITextKitExample.xcodeproj
```

Select the `ITextKitExample` scheme and any iOS 15 or newer simulator.
