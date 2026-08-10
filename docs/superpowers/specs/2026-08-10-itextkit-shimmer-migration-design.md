# ITextKit Shimmer Migration Design

## Summary

Migrate the complete text-highlight sweep behavior from the standalone
`IShimmerText` package into the existing `ITextKit` product and module. The
migration keeps the current native SwiftUI and UIKit rendering behavior while
renaming the public types for the ITextKit namespace. It does not preserve the
old package's public names or add compatibility wrappers because the current
workspace has no consumers outside the standalone package itself.

The shimmer remains a decorative treatment for real text. It does not become a
new text-content control, a generic effect pipeline, or part of
`ITextPlaybackState`.

## Goals

- Provide the existing Working-style highlight sweep from `import ITextKit`.
- Preserve SwiftUI and UIKit behavior for plain and attributed text, multiline
  layout, semantic directions, Dynamic Type, dynamic colors, Reduce Motion,
  accessibility, window and foreground lifecycle, and idempotent animation.
- Use ITextKit-specific public names with complete semantic DocC comments.
- Keep configuration resolution and geometry deterministic and shared between
  the framework-specific renderers.
- Keep the package at iOS 15, Swift tools 5.10, zero dependencies, and one
  product and module.

## Non-Goals

- Compatibility aliases or wrappers for `IShimmerText*` names.
- Changes to or deletion of the standalone `IShimmerText` repository.
- A concrete SwiftUI shimmer view that owns text content.
- Integration with `ITextPlaybackState` or the display-link implementation.
- Custom gradient profiles, timing curves, inter-sweep delays, arbitrary
  `ShapeStyle` input, shaders, timers, `TimelineView`, `Canvas`, or Metal.
- A generic text-effect protocol, type eraser, composition pipeline, or engine.
- Markdown rendering or motion composition.

## Public Interface

```swift
/// A semantic direction for a text highlight sweep.
public enum ITextShimmerDirection: Sendable, Equatable, Hashable {
    /// Travels from the leading text edge to the trailing text edge.
    case leadingToTrailing

    /// Travels from the trailing text edge to the leading text edge.
    case trailingToLeading
}

/// Configures the timing and appearance of a text highlight sweep.
public struct ITextShimmerConfiguration: Sendable, Equatable {
    public var duration: TimeInterval
    public var bandWidth: CGFloat
    public var intensity: CGFloat
    public var direction: ITextShimmerDirection

    public init(
        duration: TimeInterval = 1.5,
        bandWidth: CGFloat = 0.28,
        intensity: CGFloat = 0.85,
        direction: ITextShimmerDirection = .leadingToTrailing
    )

    public static let `default`: Self
}

public extension View {
    func shimmerText(
        isActive: Bool = true,
        configuration: ITextShimmerConfiguration = .default,
        highlight: Color = .primary
    ) -> some View
}

@MainActor
public final class ITextShimmerLabel: UILabel {
    public var isShimmering: Bool
    public var configuration: ITextShimmerConfiguration
    public var highlightColor: UIColor
}
```

`ITextShimmerLabel` inherits `UILabel` directly. It exposes normal UILabel
content and layout properties instead of adding parallel `text`,
`attributedText`, font, line, alignment, or sizing interfaces. Its frame and
coder initializers default to `isShimmering == false`, `configuration ==
.default`, and `highlightColor == .label`.

The standalone package's empty `IShimmerText` namespace enum is not migrated.

## Public Behavior Contract

### SwiftUI

The caller applies text typography, foreground style, line limits, and layout
before `.shimmerText(...)`. The modifier preserves the original content and
places a highlight-colored copy above it. A moving gradient mask reveals the
highlight copy. The overlay does not participate in hit testing and is hidden
from accessibility.

The modifier is declared on `View` because common SwiftUI text and layout
modifiers can erase the concrete `Text` type. The supported contract is limited
to rendered text content; applying it to arbitrary non-text views is outside the
guarantee.

Changing activation, configuration, or semantic direction removes or rebuilds
the overlay. Turning the effect off and on starts a new sweep rather than
resuming stored progress.

### UIKit

`ITextShimmerLabel` behaves as a native label and preserves its intrinsic size.
It owns one private, noninteractive, non-accessible UILabel aligned to its
bounds. The private label mirrors plain or attributed content, font, line count,
line breaking, alignment, baseline adjustment, font scaling, tightening,
preferred multiline width, and Dynamic Type behavior.

Attributed content is copied before the internal highlight foreground color is
applied. Caller-owned attributed strings are never mutated. Dynamic UIColor
values remain dynamic.

Each active label owns at most one `CAGradientLayer` mask and one keyed
`CABasicAnimation`. Repeated activation is idempotent. Bounds, configuration,
and semantic-direction changes replace the existing animation rather than
accumulating animations.

### Accessibility and Lifecycle

The base content remains the only accessibility element in both frameworks.
The shimmer never changes labels, traits, actions, selection, or hit testing.

Reduce Motion removes the moving overlay and leaves the complete base text
visible. UIKit also removes its mask when inactive, empty, zero-sized, detached
from a window, or configured with zero intensity. It reconciles after entering
a window, returning to the foreground, relevant trait changes, content changes,
and layout changes.

Shimmer deliberately does not use `ITextPlaybackState`. `isActive` and
`isShimmering` are request switches, not playing, paused, and stopped states.
Deactivation discards the current sweep; reactivation restarts it.

### Performance

- No `Timer`, `CADisplayLink`, `TimelineView`, `Canvas`, Metal, or per-frame
  package-owned Swift callback.
- SwiftUI adds one highlight copy and one mask only while active and allowed.
- UIKit keeps one private label and adds one mask and one Core Animation only
  while active and allowed.
- Attributed-text copying is O(n) in content length. Normal frame advancement is
  owned by the platform animation systems.

## Configuration Resolution and Error Handling

The public configuration stores exactly the values supplied by the caller.
Renderers consume an internal resolved configuration. Resolution never throws,
traps, logs, or mutates the public value.

| Value | Finite-value resolution | Non-finite fallback |
|---|---|---|
| `duration` | Clamp to `0.2...10` seconds | `1.5` seconds |
| `bandWidth` | Clamp to `0.05...1` of rendered width | `0.28` |
| `intensity` | Clamp to `0...1` | `0.85` |
| `direction` | Resolve semantic leading/trailing against RTL | Not applicable |

Conditions that prevent animation are stable rendering states, not errors. The
module displays only the base text for inactive requests, empty content, empty
bounds, off-window UIKit labels, Reduce Motion, or zero resolved intensity.

## Internal Architecture

### Core

`Sources/ITextKit/Core/ITextShimmerConfiguration.swift` owns the public
configuration and direction plus an internal immutable resolved configuration.
It does not own rendering state.

### Deterministic Rules

`Sources/ITextKit/Internal/ITextShimmerGeometry.swift` owns band width,
offscreen start and end positions, progress clamping, and semantic-to-physical
direction resolution.

`Sources/ITextKit/Internal/ITextShimmerActivationState.swift` owns the pure
decision for whether requested state, content, bounds, lifecycle, Reduce Motion,
and intensity allow an animation.

These are internal seams for deterministic tests. They are not public protocols
or adapters.

### SwiftUI Rendering

`Sources/ITextKit/SwiftUI/ITextShimmerModifier.swift` owns the public modifier
and private renderer. It uses the original content for layout, a foreground-
replaced copy for the highlight, an animated gradient mask, and a stable identity
that restarts after configuration or RTL changes.

### UIKit Rendering

`Sources/ITextKit/UIKit/ITextShimmerLabel.swift` owns the UILabel subclass,
private label synchronization, notification observation, activation
reconciliation, mask construction, keyed Core Animation, and cleanup.

SwiftUI and UIKit share only deterministic configuration and geometry. Their
native animation implementations remain separate and private. There is no port
or adapter because all dependencies are in-process system frameworks and no
implementation varies across a meaningful external seam.

## Documentation Contract

Every public declaration receives semantic `///` DocC comments. Comments must
state facts a caller needs rather than repeat the declaration. As applicable,
they document:

- units, defaults, valid ranges, and invalid-value resolution;
- semantic direction and RTL behavior;
- restart behavior when activation changes;
- inactive, empty, off-window, zero-intensity, and Reduce Motion behavior;
- SwiftUI modifier ordering;
- inherited UILabel behavior and intrinsic sizing;
- attributed-text copying and dynamic-color behavior;
- layout, hit-testing, and accessibility preservation; and
- the absence of timers, display links, and per-frame Swift work.

Internal comments explain invariants, ownership, and why platform-specific
behavior exists. They do not narrate individual statements.

## Testing Strategy

### Core Tests

Move and rename deterministic coverage into `ITextKitCoreTests`:

- confirmed defaults;
- finite clamping and non-finite fallback;
- semantic direction resolution in LTR and RTL;
- band geometry and progress in both physical directions; and
- activation conditions for requests, content, bounds, window, Reduce Motion,
  and intensity.

### SwiftUI Tests

Add interface construction coverage to `ITextKitSwiftUITests` for default and
fully configured modifiers on plain, attributed, single-line, and multiline
text. Example UI coverage exercises the visible SwiftUI entry points and stable
base text. The overlay remains hidden from accessibility and hit testing.

### UIKit Tests

Add behavior coverage to `ITextKitUIKitTests` for:

- public defaults and plain-content synchronization;
- attributed-text copying and highlight-only foreground replacement;
- mirroring of native drawing and sizing properties;
- exactly one mask and keyed animation after repeated activation;
- animation endpoint replacement after bounds changes;
- duration replacement after configuration changes;
- cleanup after deactivation and window removal;
- suppression for empty and off-window labels; and
- unchanged intrinsic sizing and accessibility ownership.

Tests observe behavior through the public interface wherever possible. Pure
configuration, activation, and geometry tests use the internal seams through
`@testable import ITextKit`.

## Documentation and Example Migration

- Add shimmer usage and behavior to the root README.
- Add a dedicated DocC shimmer guide and link it from the DocC overview.
- Update accessibility and lifecycle documentation with the separate shimmer
  request-switch contract.
- Add SwiftUI and UIKit shimmer examples to the offline Example application.
- Add Example UI coverage for both entry points.
- Add the feature to CHANGELOG under an Unreleased section until a release is
  explicitly requested.
- Remove the shimmer migration item from ROADMAP only after implementation,
  documentation, and verification are complete.
- Remove Markdown rendering and motion composition from ROADMAP immediately, as
  separately requested.

## Verification and Completion Criteria

The migration is complete only when all of the following are true:

1. `swift package dump-package` succeeds.
2. ITextKit package simulator tests pass.
3. A generic iOS ITextKit build passes with code signing disabled.
4. ITextKit DocC builds for an iOS Simulator destination.
5. The offline Example application builds.
6. Example UI tests pass for existing controls and both shimmer integrations.
7. `git diff --check` passes.
8. A repository search finds no unintended `IShimmerText*` public names in
   ITextKit.
9. README, DocC, Example, CHANGELOG, and ROADMAP agree with the implemented
   interface and behavior.
10. The standalone `IShimmerText` repository remains unchanged.

Retiring, deleting, tagging, or archiving the standalone package is a separate
operation that requires explicit authorization after the ITextKit migration has
been released and verified.
