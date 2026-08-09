# Attributed Text

Use native rich-text values without adding another content abstraction.

## Framework-Native Input

SwiftUI controls accept `AttributedString` through `ITextRotator(attributedTexts:configuration:playbackState:)`, `ITextMarquee(attributedText:configuration:playbackState:)`, and `ITextTypewriter(attributedText:configuration:)`. UIKit controls accept `NSAttributedString` through matching explicit initializer labels and mutable properties.

Plain APIs remain available. UIKit `text`/`texts` and `attributedText`/`attributedTexts` describe the same current content. Assigning a plain value replaces rich content and drops all attributes; reading a plain property strips attributes from the current value.

## Visual Contract

The shared inline visual contract covers font (including size and weight), color, kern, underline, strikethrough, and baseline attributes. UIKit also honors native `NSParagraphStyle`. On iOS 15, SwiftUI paragraph layout is expressed with view-level modifiers such as `multilineTextAlignment` rather than an inline `AttributedString` paragraph style. Inline attributes take precedence over view-level font and color defaults.

Unknown or custom attributes remain available to the native renderer but have no cross-framework rendering guarantee. Attachments are not a dedicated supported feature. Link metadata or appearance may survive native rendering, but controls do not provide link interaction and are intentionally noninteractive.

SwiftUI relative `Font` values follow SwiftUI Dynamic Type behavior. In UIKit, ranges without an explicit font use the view's `font` and `adjustsFontForContentSizeCategory`; explicit `UIFont` runs remain the caller's responsibility. Pixel-identical output between SwiftUI and UIKit is not promised.

## Ownership and Reset

UIKit copies each attributed value at assignment, so later mutation of a caller-owned `NSMutableAttributedString` does not alter the view.

Equality includes characters and all attributes. A character or style-only replacement resets a rotator to its first item for a complete interval, returns a marquee to semantic leading, or restarts a typewriter from an empty prefix. Explicit playing, paused, or stopped state is preserved for rotator and marquee; typewriter has no explicit playback state.

## Accessibility and Interaction

Each control exposes one accessibility element containing plain characters only. A typewriter exposes the complete value from the start rather than announcing each prefix. Outgoing, incoming, measurement, and repeated visual copies remain hidden. Rich-text input does not add gestures or link handling.
