# ``ITextKit``

Present plain, attributed, or vector-styled text with native rotation, marquee, typewriter, and shimmer effects in SwiftUI and UIKit.

## Overview

ITextKit ships one Swift Package product and one module. A mixed application can use `import ITextKit` from both SwiftUI and UIKit sources while choosing the framework-native control at each call site.

Use ``ITextRotator`` or ``ITextRotatorView`` for a sequence of variable-height messages. Use ``ITextMarquee`` or ``ITextMarqueeView`` for one overflowing line. Use ``ITextTypewriter`` or ``ITextTypewriterView`` for an independent one-shot reveal whose ideal size follows the visible prefix. Use `.shimmerText(...)` or ``ITextShimmerLabel`` for a repeating decorative highlight sweep over real text.

Use ``ITextStyledText`` or ``ITextStyledLabel`` for continuous linear-gradient fill and exact outward outlines. See <doc:StyledText> for geometry, rich-text ownership, RTL, Dynamic Type, and effect composition.

Every control has a plain `String` API and an explicit framework-native attributed API. See <doc:AttributedText> for supported attributes, reset rules, accessibility, and mutability semantics.

ITextKit is a component library for text presentation. It is not an API wrapper around Apple's TextKit text-layout framework.

## Topics

### Rotation

- <doc:TextRotator>
- ``ITextRotator``
- ``ITextRotatorView``
- ``ITextRotatorConfiguration``

### Marquee

- <doc:TextMarquee>
- ``ITextMarquee``
- ``ITextMarqueeView``
- ``ITextMarqueeConfiguration``

### Typewriter

- <doc:TextTypewriter>
- ``ITextTypewriter``
- ``ITextTypewriterView``
- ``ITextTypewriterConfiguration``

### Shimmer

- <doc:TextShimmer>
- ``ITextShimmerLabel``
- ``ITextShimmerConfiguration``
- ``ITextShimmerDirection``

### Playback

- <doc:PlaybackAndLifecycle>
- ``ITextPlaybackState``

### Content

- <doc:AttributedText>
- <doc:StyledText>
- ``ITextStyledText``
- ``ITextStyledLabel``
