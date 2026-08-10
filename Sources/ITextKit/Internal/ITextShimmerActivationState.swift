import CoreGraphics

/// Centralizes the conditions under which a shimmer renderer may own animation.
///
/// SwiftUI supplies the conditions it can observe declaratively. UIKit uses the
/// same rule while reconciling content, layout, window, accessibility, and
/// configuration changes.
enum ITextShimmerActivationState {
    /// Returns whether every content, layout, lifecycle, and motion condition
    /// currently permits a highlight sweep.
    ///
    /// - Parameters:
    ///   - isRequested: Whether the caller requests the decorative effect.
    ///   - hasContent: Whether the underlying text contains characters.
    ///   - hasBounds: Whether the renderer has nonempty layout bounds.
    ///   - isInWindow: Whether the renderer participates in a visible hierarchy.
    ///   - reduceMotion: Whether nonessential motion is disabled.
    ///   - intensity: Resolved highlight-copy opacity multiplier.
    /// - Returns: `true` only when starting or retaining animation is valid.
    static func shouldAnimate(
        isRequested: Bool,
        hasContent: Bool,
        hasBounds: Bool,
        isInWindow: Bool,
        reduceMotion: Bool,
        intensity: CGFloat
    ) -> Bool {
        isRequested &&
            hasContent &&
            hasBounds &&
            isInWindow &&
            !reduceMotion &&
            intensity > 0
    }
}
