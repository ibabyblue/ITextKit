import SwiftUI

/// Adds text-specific presentation treatments to SwiftUI views.
public extension View {
    /// Adds a repeating highlight sweep to rendered text.
    ///
    /// Apply text-rendering modifiers such as font, foreground style, line
    /// limits, and multiline alignment before this modifier. Apply outer
    /// layout and decoration such as frame expansion, padding, background, and
    /// container overlays afterward. The modifier copies the content exactly
    /// at its call site, so a background applied earlier would also appear in
    /// the moving highlight copy. The original content remains the sole layout,
    /// hit-testing, and accessibility owner. The overlay is omitted when
    /// `isActive` is `false`, Reduce Motion is enabled, or resolved intensity is
    /// zero. Deactivation discards progress, so later reactivation starts a
    /// complete sweep. Semantic direction follows the current layout direction.
    ///
    /// The modifier is available on `View` because common SwiftUI modifiers can
    /// erase the concrete `Text` type. Its supported rendering contract is text
    /// content; applying it to an arbitrary non-text view is not guaranteed.
    /// Native SwiftUI animation advances frames without a package timer,
    /// display link, `TimelineView`, or per-frame Swift callback.
    ///
    /// - Parameters:
    ///   - isActive: Whether the caller requests shimmer. The default is `true`.
    ///   - configuration: Sweep timing and appearance. The default is
    ///     ``ITextShimmerConfiguration/default``.
    ///   - highlight: Dynamic highlight color. The default is `Color.primary`.
    /// - Returns: The original content with an optional noninteractive overlay.
    func shimmerText(
        isActive: Bool = true,
        configuration: ITextShimmerConfiguration = .default,
        highlight: Color = .primary
    ) -> some View {
        modifier(ITextShimmerModifier(
            isActive: isActive,
            configuration: configuration,
            highlight: highlight
        ))
    }
}

/// Applies environment rules before creating one native animated overlay.
private struct ITextShimmerModifier: ViewModifier {
    /// Whether the caller currently requests the decorative effect.
    let isActive: Bool

    /// Caller-provided values resolved only when rendering.
    let configuration: ITextShimmerConfiguration

    /// Dynamic color applied to the highlight copy.
    let highlight: Color

    /// Whether the system currently disables nonessential motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Semantic direction used to resolve leading and trailing edges.
    @Environment(\.layoutDirection) private var layoutDirection

    /// Preserves base content and conditionally overlays its highlight copy.
    ///
    /// - Parameter content: Original caller-owned content and layout.
    /// - Returns: Content with no overlay or one noninteractive overlay.
    func body(content: Content) -> some View {
        let resolved = configuration.resolved
        let isRightToLeft = layoutDirection == .rightToLeft

        return content.overlay {
            if isActive, !reduceMotion, resolved.intensity > 0 {
                ITextShimmerAnimatedOverlay(
                    content: content,
                    configuration: resolved,
                    highlight: highlight,
                    direction: resolved.direction.resolved(
                        isRightToLeft: isRightToLeft
                    )
                )
                .id(ITextShimmerAnimationIdentity(
                    configuration: resolved,
                    isRightToLeft: isRightToLeft
                ))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
}

/// Restarts native animation only after configuration or RTL changes.
private struct ITextShimmerAnimationIdentity: Hashable {
    /// Finite, range-safe renderer values.
    let configuration: ITextShimmerResolvedConfiguration

    /// Whether leading is currently the physical right edge.
    let isRightToLeft: Bool
}

/// Reveals a highlight rectangle through the complete rendered content alpha
/// and then through a moving gradient band.
private struct ITextShimmerAnimatedOverlay<Content: View>: View {
    /// Content copy whose layout exactly matches the original view.
    let content: Content

    /// Finite timing, width, intensity, and semantic direction values.
    let configuration: ITextShimmerResolvedConfiguration

    /// Dynamic foreground color applied to the content copy.
    let highlight: Color

    /// Physical direction resolved for the current SwiftUI environment.
    let direction: ITextShimmerTravelDirection

    /// Normalized mask position animated by SwiftUI from zero to one.
    @State private var progress: CGFloat = 0

    /// Builds one alpha-masked overlay and hands frame advancement to SwiftUI.
    var body: some View {
        Rectangle()
            .fill(highlight.opacity(Double(configuration.intensity)))
            .mask { content }
            .mask {
                GeometryReader { proxy in
                    let geometry = ITextShimmerGeometry(
                        containerWidth: proxy.size.width,
                        bandFraction: configuration.bandWidth
                    )

                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.35),
                            .black,
                            .black.opacity(0.35),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(
                        width: geometry.bandWidth,
                        height: proxy.size.height
                    )
                    .position(
                        x: geometry.center(
                            at: progress,
                            direction: direction
                        ),
                        y: proxy.size.height / 2
                    )
                }
            }
            .onAppear {
                progress = 0
                withAnimation(
                    .linear(duration: configuration.duration)
                        .repeatForever(autoreverses: false)
                ) {
                    progress = 1
                }
            }
    }
}
