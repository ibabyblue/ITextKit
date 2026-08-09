# ``ITextKit``

Present plain text with native rotation and marquee motion in SwiftUI and UIKit.

## Overview

ITextKit ships one Swift Package product and one module. A mixed application can use `import ITextKit` from both SwiftUI and UIKit sources while choosing the framework-native control at each call site.

Use ``ITextRotator`` or ``ITextRotatorView`` for a sequence of variable-height messages. Use ``ITextMarquee`` or ``ITextMarqueeView`` for one overflowing line. Both families share configuration and playback semantics without exposing their internal timing engine.

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

### Playback

- <doc:PlaybackAndLifecycle>
- ``ITextPlaybackState``
