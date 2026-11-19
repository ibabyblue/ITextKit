# Image Canvas

Edit plain text around independently movable and rotatable images in UIKit and SwiftUI.

## Ownership

``ITextCanvasView`` owns a native `UITextView`, image views, gestures, and a shared layout engine.
``ITextCanvas`` adapts that same implementation with a document binding. Text remains editable
through the system input method, selection, copy, and paste. The canvas uses uniform body
typography; styled gradient text and rich-text formatting controls are separate ITextKit features.

``ITextCanvasDocument`` stores text and ordered ``ITextCanvasImage`` placements. Encode/decode
the document with `JSONEncoder`/`JSONDecoder`. The caller loads images and supplies a fast
`imageProvider` lookup. A missing image retains a placeholder of the saved size. Loading a new
bitmap does not change that size; explicitly change `aspectRatio` to change geometry.

The module does not select photos, upload files, load URLs, enforce a business text/image limit,
or save documents automatically. The example shows offline image insertion, text editing,
rotation, document history, saving/restoring, and read-only mode in both frameworks.

## Geometry and wrapping

`anchorOffset` counts UTF-16 code units in the complete text. Baseline layout excludes image
avoidance: each image is positioned relative to its anchor line in this independent text layout.
The final visible text then wraps around the images. Wrapped text never moves its own anchor,
preventing a feedback loop during manipulation.

`xRatio`, `yOffset`, and `widthRatio` use the text container's usable width, after content insets.
`xRatio` is the physical left edge before rotation. `yOffset` is the unrotated top relative to the
baseline anchor line. `rotationDegrees` is clockwise about the image center. `aspectRatio` is
width divided by height. Placement IDs identify individual uses of a resource, not the asset.

The default `.rotatedRectangle` wraps along the tilted rectangle with `imageSpacing` clearance.
`.boundingBox` provides a conservative horizontal exclusion rectangle. Neither mode extracts
the opaque silhouette of transparent PNGs. Text remains horizontal; only images rotate.

Right-to-left paragraphs use one native line fragment per row to avoid TextKit 1 overlapping
later paragraphs when a row is split into two columns. This can leave more whitespace on the
opposite side of a picture. Arabic shaping remains native, and subsequent paragraphs advance
normally. Left-to-right paragraphs can use both available sides of an image.

Rendering clamps unsafe dimensions, keeps images inside horizontal bounds and above the top,
and resolves collisions in stable array order. The default prevents overlap; set
`allowsImageOverlap` to allow it. A gesture proposal intersecting another image is rejected
without moving its neighbors. An image wider than the container after rotation is scaled down
to fit. There is no bottom boundary, so dragging downward can extend content.

Viewport/font changes recompute display geometry without overwriting the saved document.
Different widths and font metrics naturally produce different line breaks. Editing and
read-only views with the same width, typography, and document produce the same layout.

## Interaction and history

Long-press an image to move it. Two-finger rotation can start directly or join an active drag.
Only recognizers on the same image cooperate. Finger-count changes rebase translation to avoid
jumps. While manipulating an image, the canvas suspends ancestor scroll views and restores
their previous enabled states on completion, cancellation, removal, or window deactivation.
There is no edge auto-scroll during a gesture; release, scroll, then continue moving the image.

Temporary poses remain internal. `onDocumentChange` publishes once on successful gesture
completion. Cancellation restores the original pose. Text edits publish after a committed
input change; a complete marked-text composition is one history entry. Image operations and
text changes share a bounded, 100-operation document history, including anchor restoration.

Use `undo()`, `redo()`, or the canvas's `undoManager`; hardware Command-Z and Shift-Command-Z
also operate on the document. The inner text view's independent text-only history is disabled.
Applications can provide undo/redo buttons using `canUndo` and `canRedo`; the example does so.
The canvas does not provide system shake-to-undo or a three-finger editing toolbar.

An equal external document assignment is ignored. A different assignment replaces content and
clears history. During marked input, the latest different external document is deferred until
composition commits; a SwiftUI echo of the last published value is ignored. Coordinate external
document replacement with your application's edit/conflict policy.

## Layout integration and accessibility

Use a bounded frame for internal scrolling. In UIKit, setting `isScrollEnabled = false` exposes
full intrinsic height for an outer scroll view. `contentHeight` and `onContentHeightChange`
allow integration with custom page layout. The SwiftUI adapter uses internal scrolling and
preserves the native editor across binding updates.

Use `accessibilityLabel` to describe each picture. Images expose rotation and removal actions
to VoiceOver. Text uses the system editor's accessibility. Natural alignment follows text
direction; image coordinates remain physical. Preferred fonts can follow Dynamic Type.

## Performance

The baseline layout is rebuilt only for text, width, or font/alignment changes. During image
movement, the module reuses image views and decoded bitmaps, updates native rotated exclusion
paths, and invalidates affected text paragraphs. UIKit batches repeated gesture changes into layout
passes. Images are never downloaded or decoded in the gesture callback.

The test suite measures complete native layouts for 2,000 characters / 6 images and 10,000
characters / 20 images, plus paced display-link interaction. It asserts unchanged baseline
generation and no repeated image-provider work during movement. Device and simulator timings
must be reported separately; CPU layout time alone is not a frame-rate measurement.
