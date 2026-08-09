# Revealing Text One Character at a Time

Display a single value as an automatic one-shot reveal whose ideal size follows its visible prefix.

## Supply Text

``ITextTypewriter`` accepts a `String` or `AttributedString`. ``ITextTypewriterView`` accepts a `String` or `NSAttributedString`. The control reveals complete Swift `Character` values, so an extended grapheme cluster such as a family emoji appears atomically. Rich attributes remain attached to every revealed run.

```swift
ITextTypewriter(
    text: String(localized: "A message revealed one character at a time"),
    configuration: .init(charactersPerSecond: 20, initialDelay: 0)
)
```

After the initial delay, the first character appears immediately. Later characters use ``ITextTypewriterConfiguration/charactersPerSecond``. A slow frame may reveal multiple characters so presentation stays aligned with elapsed real time. The full value remains visible after completion.

## Constrain Layout

Before its first character, the visual ideal size is zero. Width and height then follow the current prefix. ITextKit does not provide a maximum-width property: apply normal layout at the call site and let native text wrapping determine when the height grows.

```swift
ITextTypewriter(text: "This value can wrap as it grows")
    .frame(maxWidth: 280, alignment: .leading)
```

```swift
let view = ITextTypewriterView(text: "This value can wrap as it grows")
view.numberOfLines = 0
view.widthAnchor.constraint(lessThanOrEqualToConstant: 280).isActive = true
```

Changing the actual text, any inline attribute, or timing configuration restarts from an empty prefix. Reassigning equal content is ignored. View-level styling, Dynamic Type, or available-width changes remeasure the visible prefix without restarting it.

## Automatic Lifecycle

Typewriter is independent of rotator and marquee playback. It has no playback state or public start, pause, resume, stop, restart, progress, cursor, callback, gesture, sound, or haptic API.

Content assigned outside an active hierarchy consumes no time. Becoming visible in an active scene starts it; leaving freezes exact progress; returning resumes. Empty content stays at zero size and starts no timing work.

## Accessibility and Motion

VoiceOver sees one complete plain-text value from the start, with no per-character announcements. When Reduce Motion is enabled, the complete text appears immediately. Turning Reduce Motion off does not replay content that was completed this way. Right-to-left input is revealed in logical string order and rendered with native layout.
