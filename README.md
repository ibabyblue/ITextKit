# ITextKit

Native text motion controls for SwiftUI and UIKit, delivered as one Swift Package product and one import.

![iOS 15+](https://img.shields.io/badge/iOS-15%2B-blue)
![Swift 5.10+](https://img.shields.io/badge/Swift-5.10%2B-orange)
![Release 0.1.0](https://img.shields.io/badge/release-0.1.0-purple)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

ITextKit is a UI component library for text presentation. It is not a wrapper around Apple's TextKit text-layout framework.

## Features

- `ITextRotator` and `ITextRotatorView` rotate through variable-height text with an upward fade
- `ITextMarquee` and `ITextMarqueeView` move one overflowing line in a seamless loop
- Plain `String` APIs plus native `AttributedString` and `NSAttributedString` input
- One package product and one module: `import ITextKit` in SwiftUI, UIKit, or mixed targets
- Declarative SwiftUI playback and imperative UIKit playback
- Exact pause/resume for remaining delays, transition progress, height, and marquee offset
- Lifecycle suspension that preserves explicit playback state and progress
- Reduce Motion, right-to-left layout, Dynamic Type, and VoiceOver-aware rendering
- No gestures, indicators, third-party dependencies, or runtime network access

## Requirements

| | Minimum |
|---|---|
| iOS | 15.0 |
| Swift tools | 5.10 |
| Xcode | 15.3 |

## Installation

In Xcode, choose **File → Add Package Dependencies** and add the repository URL. Select the `ITextKit` product.

For a `Package.swift` dependency:

```swift
dependencies: [
    .package(url: "https://github.com/ibabyblue/ITextKit.git", from: "0.1.0")
]
```

Add the product to an application target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "ITextKit", package: "ITextKit")
    ]
)
```

Every source file uses the same import:

```swift
import ITextKit
```

The module contains both SwiftUI and UIKit public APIs. Importing it does not force a source file to import either framework explicitly; add `import SwiftUI` or `import UIKit` only when that file otherwise needs the framework.

## Text Rotator

The rotator accepts caller-localized plain or attributed values. Empty input renders nothing. One value stays static. Multiple values cycle indefinitely, including the last-to-first transition. Duplicate values are valid independent items.

### SwiftUI

```swift
import ITextKit
import SwiftUI

struct StatusView: View {
    @State private var playback: ITextPlaybackState = .playing

    let messages = [
        String(localized: "Preparing your space"),
        String(localized: "This longer message can wrap onto another line")
    ]

    var body: some View {
        ITextRotator(
            texts: messages,
            configuration: .init(interval: 3, transitionDuration: 0.35),
            playbackState: playback
        )
        .onTextRotatorChange { index, text in
            print("Settled at \(index): \(text)")
        }
        .font(.headline)
        .multilineTextAlignment(.center)
    }
}
```

The ideal height follows the settled text. During a transition it is the maximum of the outgoing and incoming heights, then resolves to the incoming height. A caller may still impose a fixed frame when product layout requires one.

Replacing `texts` resets to the first item and waits a complete interval. The callback runs only after a new item settles; initial display, pause, and stop do not invoke it.

### UIKit

```swift
import ITextKit
import UIKit

let rotator = ITextRotatorView(
    texts: ["Preparing your space", "A longer status that wraps naturally"]
)
rotator.font = .preferredFont(forTextStyle: .headline)
rotator.textAlignment = .center
rotator.numberOfLines = 0
rotator.onTextChange = { index, text in
    print("Settled at \(index): \(text)")
}

rotator.pause()
rotator.resume()
rotator.stop()
rotator.start()
```

`ITextRotatorView` invalidates its intrinsic content size as presentation changes. It never changes ancestor constraints and never calls `layoutIfNeeded()` on an ancestor; the owning layout decides how to react.

## Attributed Text

Use explicit rich-input labels so plain and attributed call sites remain unambiguous:

```swift
// SwiftUI
var status = AttributedString("Important status")
status.font = .headline.bold()
status.foregroundColor = .purple
status.underlineStyle = .single

let rotator = ITextRotator(attributedTexts: [status])
let marquee = ITextMarquee(attributedText: status)
```

```swift
// UIKit
let status = NSAttributedString(
    string: "Important status",
    attributes: [
        .font: UIFont.preferredFont(forTextStyle: .headline),
        .foregroundColor: UIColor.systemPurple,
        .underlineStyle: NSUnderlineStyle.single.rawValue
    ]
)

let rotator = ITextRotatorView(attributedTexts: [status])
let marquee = ITextMarqueeView(attributedText: status)
```

The shared inline visual contract covers font (including size and weight), color, kern, underline, strikethrough, and baseline attributes. UIKit also honors native `NSParagraphStyle`; on iOS 15 SwiftUI paragraph layout remains view-level through modifiers such as `multilineTextAlignment`. Inline attributes win over view-level defaults such as `font` and `textColor`. Other native or custom attributes are passed to the platform renderer without an ITextKit rendering guarantee. Attachments are not a dedicated feature, and link interaction is intentionally unavailable because motion controls are noninteractive.

UIKit takes immutable copies on assignment. `texts`/`text` and `attributedTexts`/`attributedText` are two views of the same current content: assigning plain text drops attributes, while reading plain text returns stripped characters. A style-only rich-text change resets the control just like a character change and preserves the explicit playing, paused, or stopped state.

SwiftUI relative fonts and UIKit preferred fonts without explicit per-range overrides follow each framework's Dynamic Type behavior. Explicit `UIFont` runs remain caller-owned. The settled callback continues to return `(Int, String)`; use its index to retrieve the original rich value when needed.

## Text Marquee

The marquee accepts one caller-localized plain or attributed value and always renders a single line. Text that fits remains static. Overflowing text waits at semantic leading for one second by default, then uses two inaccessible copies for a seamless loop. Supply semantic single-line content; embedded newlines follow native one-line label behavior and are not rewritten by ITextKit.

### SwiftUI

```swift
ITextMarquee(
    text: String(localized: "A long announcement that may exceed the available width"),
    configuration: .init(speed: 30, spacing: 24, initialDelay: 1),
    playbackState: .playing
)
.font(.body)
```

### UIKit

```swift
let marquee = ITextMarqueeView(
    text: "A long announcement that may exceed the available width"
)
marquee.font = .preferredFont(forTextStyle: .body)
marquee.textColor = .secondaryLabel

marquee.pause()
marquee.resume()
```

Motion travels left in left-to-right layout and right in right-to-left layout. Changing text, font, bounds, layout direction, or configuration resets to semantic leading and reapplies the initial delay.

## Playback Contract

`ITextPlaybackState` has three values:

- `.playing` advances whenever the view and application scene are active
- `.paused` freezes exact remaining delay and exact in-flight presentation progress
- `.stopped` discards progress; a rotator keeps its last settled item and a marquee returns to leading

SwiftUI receives playback state in each initializer. UIKit provides `start()`, `pause()`, `resume()`, and `stop()`. Calling `resume()` when not paused is a no-op. Calling `start()` always starts a complete stable cycle and intentionally discards paused progress.

Leaving a window, disappearing, or moving to an inactive application scene suspends time without changing the caller's explicit state. Returning resumes from the exact saved position when state is still `.playing`.

## Accessibility and Motion

- Internal transition and repeated-copy labels are hidden from accessibility
- VoiceOver sees only the current rotator characters or the real marquee characters, without attributes
- Automatic rotation does not post announcements
- Reduce Motion turns rotator movement into a cross-fade
- Reduce Motion stops marquee movement and shows one tail-truncated line

## Configuration Resolution

Public configuration values remain the values supplied by the caller. Renderers resolve invalid input consistently:

| Value | Resolution |
|---|---|
| Rotator `interval <= 0` | automatic rotation disabled |
| Rotator `transitionDuration < 0` | `0` |
| Marquee `speed <= 0` | static text |
| Negative marquee spacing or delay | `0` |
| Any non-finite value | that property's default |

## Documentation and Example

- [DocC overview](Sources/ITextKit/Documentation.docc/ITextKit.md)
- [Rotator guide](Sources/ITextKit/Documentation.docc/TextRotator.md)
- [Marquee guide](Sources/ITextKit/Documentation.docc/TextMarquee.md)
- [Attributed text contract](Sources/ITextKit/Documentation.docc/AttributedText.md)
- [Playback and lifecycle](Sources/ITextKit/Documentation.docc/PlaybackAndLifecycle.md)
- [Offline SwiftUI and UIKit example](Example/README.md)
- [Roadmap](ROADMAP.md)

## License

ITextKit is available under the MIT license. See [LICENSE](LICENSE). Release history is maintained in [CHANGELOG.md](CHANGELOG.md).
