# Playback and Lifecycle

Separate caller intent from temporary environment suspension.

## Explicit State

``ITextPlaybackState/playing`` advances time, ``ITextPlaybackState/paused`` freezes exact progress, and ``ITextPlaybackState/stopped`` discards progress. SwiftUI accepts this value declaratively in each control initializer.

UIKit exposes four methods on both controls:

- `start()` discards any progress and starts a complete stable cycle
- `pause()` freezes the current remaining delay or visual position
- `resume()` continues only when paused
- `stop()` discards progress and returns to the stable stopped presentation

For a rotator, stopped presentation is the last fully settled item. For a marquee, it is semantic leading.

## Exact Suspension

The package advances deterministic state from display-link deltas instead of handing timing ownership to an opaque repeating animation. A pause therefore retains the remaining settled interval, transition offset, opacity, intermediate rotator height, marquee initial delay, and marquee offset.

## Environment Suspension

When a UIKit view leaves its window, a SwiftUI view disappears, or the application scene becomes inactive, ITextKit stops its display link but does not modify explicit playback state. If the same view returns while state remains playing, it continues from its saved position.

## Automatic Typewriter Lifecycle

``ITextTypewriter`` and ``ITextTypewriterView`` do not use ``ITextPlaybackState`` and do not expose `start()`, `pause()`, `resume()`, or `stop()`. Assigning content arms a one-shot reveal. Time begins only after the view is visible in an active scene, freezes at the exact prefix and fractional character interval when inactive, and resumes when active again. Once complete, content remains complete across later visibility changes.
