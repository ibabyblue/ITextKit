# Moving One Overflowing Line

Keep short text still and move long text at a constant semantic speed.

## Overflow Behavior

``ITextMarquee`` and ``ITextMarqueeView`` measure the complete untruncated line against the available viewport. Text that fits uses one static label. Overflowing text waits for ``ITextMarqueeConfiguration/initialDelay`` and then moves two identical visual copies separated by ``ITextMarqueeConfiguration/spacing``.

The visual copies are hidden from accessibility. VoiceOver receives only the original string.

```swift
ITextMarquee(
    text: String(localized: "A long live-status message"),
    configuration: .init(speed: 30, spacing: 24, initialDelay: 1)
)
```

## Semantic Direction

Left-to-right environments move content left. Right-to-left environments move it right. A layout-direction change resets the content to semantic leading and reapplies the initial delay.

Text, font, available width, and configuration changes use the same reset rule. A nonpositive speed keeps the static tail-truncated presentation.

## Reduce Motion

When Reduce Motion is enabled, the marquee stops advancing and displays one tail-truncated line. Disabling Reduce Motion can continue the caller's unchanged playback state.
