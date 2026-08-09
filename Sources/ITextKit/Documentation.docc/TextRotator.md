# Rotating Variable-Height Text

Cycle through localized messages without imposing one permanent banner height.

## Supply Plain Text

Localize strings before passing them to ITextKit. An empty array renders nothing, one item remains static, and two or more items cycle from the last item back to the first. Duplicate strings remain distinct array positions.

```swift
ITextRotator(
    texts: [
        String(localized: "Connecting"),
        String(localized: "This may take a little longer than usual")
    ]
)
```

The settled text occupies the view's ideal height. During the upward fade, both outgoing and incoming text participate in measurement so the transition uses their maximum height. After settlement, the ideal height becomes the new text height.

UIKit exposes the same behavior through ``ITextRotatorView/intrinsicContentSize``. The view invalidates its own intrinsic size but does not force an ancestor layout pass.

## Observe Settlement

SwiftUI uses ``ITextRotator/onTextRotatorChange(_:)`` and UIKit uses ``ITextRotatorView/onTextChange``. Callbacks happen only after the incoming item fully settles. They do not happen for initial display or when an in-flight transition is paused or stopped.

## Reset Content

Replacing the text array resets the rotator to index zero and starts a complete interval. Changing timing configuration keeps the last settled item, cancels any in-flight transition, and also starts a complete interval.
