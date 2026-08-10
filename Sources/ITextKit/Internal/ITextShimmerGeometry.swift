import CoreGraphics

/// Resolves a semantic shimmer direction only when the current layout direction
/// is known, so configuration values remain independent of one presentation.
extension ITextShimmerDirection {
    /// Returns the physical horizontal direction for the current interface.
    ///
    /// - Parameter isRightToLeft: Whether leading is the physical right edge.
    /// - Returns: The direction used by deterministic geometry and renderers.
    func resolved(isRightToLeft: Bool) -> ITextShimmerTravelDirection {
        switch (self, isRightToLeft) {
        case (.leadingToTrailing, false), (.trailingToLeading, true):
            return .leftToRight
        case (.leadingToTrailing, true), (.trailingToLeading, false):
            return .rightToLeft
        }
    }
}

/// A physical horizontal direction used after semantic layout resolution.
enum ITextShimmerTravelDirection: Sendable, Equatable, Hashable {
    /// Travels toward increasing x coordinates.
    case leftToRight

    /// Travels toward decreasing x coordinates.
    case rightToLeft
}

/// Resolves one horizontal highlight band's width and travel positions.
struct ITextShimmerGeometry: Sendable, Equatable {
    /// Nonnegative width occupied by the rendered text.
    let containerWidth: CGFloat

    /// Highlight-band width in points.
    let bandWidth: CGFloat

    /// Creates geometry from rendered width and a resolved band fraction.
    ///
    /// A negative container width behaves as zero. Callers provide a range-safe
    /// band fraction from ``ITextShimmerConfiguration`` resolution.
    ///
    /// - Parameters:
    ///   - containerWidth: Rendered text width in points.
    ///   - bandFraction: Band width relative to the rendered text width.
    init(containerWidth: CGFloat, bandFraction: CGFloat) {
        self.containerWidth = max(containerWidth, 0)
        bandWidth = self.containerWidth * bandFraction
    }

    /// Center position that places the complete band immediately left of text.
    var leftOffscreenCenter: CGFloat {
        -bandWidth / 2
    }

    /// Center position that places the complete band immediately right of text.
    var rightOffscreenCenter: CGFloat {
        containerWidth + bandWidth / 2
    }

    /// Returns the current band center for normalized animation progress.
    ///
    /// Values below zero use the start position and values above one use the end
    /// position, preventing renderer-specific overshoot from exposing different
    /// geometry.
    ///
    /// - Parameters:
    ///   - progress: Normalized travel progress.
    ///   - direction: Resolved physical horizontal direction.
    /// - Returns: Band center in text-local coordinates.
    func center(
        at progress: CGFloat,
        direction: ITextShimmerTravelDirection
    ) -> CGFloat {
        let value = min(max(progress, 0), 1)
        let start = direction == .leftToRight
            ? leftOffscreenCenter
            : rightOffscreenCenter
        let end = direction == .leftToRight
            ? rightOffscreenCenter
            : leftOffscreenCenter
        return start + (end - start) * value
    }
}
