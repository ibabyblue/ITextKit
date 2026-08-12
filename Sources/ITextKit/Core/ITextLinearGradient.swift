import CoreGraphics

/// A normalized point inside the complete visible bounds of styled text.
///
/// Semantic leading and trailing cases follow the current layout direction.
/// ``unit(x:y:)`` uses physical `0...1` coordinates and never mirrors in RTL.
public enum ITextGradientPoint: Hashable, Sendable {
    case topLeading
    case top
    case topTrailing
    case leading
    case center
    case trailing
    case bottomLeading
    case bottom
    case bottomTrailing
    case unit(x: CGFloat, y: CGFloat)
}

/// One color and normalized location in a linear text gradient.
public struct ITextGradientStop<ColorValue> {
    /// The platform-native color stored without eager resolution.
    public var color: ColorValue

    /// Requested location along the gradient axis.
    ///
    /// Rendering clamps finite values to `0...1`. A non-finite value uses
    /// this stop's evenly distributed input position.
    public var location: CGFloat

    public init(color: ColorValue, location: CGFloat) {
        self.color = color
        self.location = location
    }
}

extension ITextGradientStop: Equatable where ColorValue: Equatable {}

/// A linear paint spanning the complete visible bounds of styled text.
///
/// Multiline text shares one coordinate space. Rendering does not restart the
/// gradient per line, glyph, or attributed run.
public struct ITextLinearGradient<ColorValue> {
    /// Caller-provided stops, preserved exactly until rendering.
    public var stops: [ITextGradientStop<ColorValue>]

    /// Start point in normalized text-bounds coordinates.
    public var startPoint: ITextGradientPoint

    /// End point in normalized text-bounds coordinates.
    public var endPoint: ITextGradientPoint

    public init(
        stops: [ITextGradientStop<ColorValue>],
        startPoint: ITextGradientPoint = .leading,
        endPoint: ITextGradientPoint = .trailing
    ) {
        self.stops = stops
        self.startPoint = startPoint
        self.endPoint = endPoint
    }

    /// Creates evenly distributed color stops.
    ///
    /// Empty input resolves as absent paint. One color resolves as a solid.
    public init(
        colors: [ColorValue],
        startPoint: ITextGradientPoint = .leading,
        endPoint: ITextGradientPoint = .trailing
    ) {
        let divisor = max(colors.count - 1, 1)
        self.stops = colors.enumerated().map { index, color in
            ITextGradientStop(
                color: color,
                location: CGFloat(index) / CGFloat(divisor)
            )
        }
        self.startPoint = startPoint
        self.endPoint = endPoint
    }
}

extension ITextLinearGradient: Equatable where ColorValue: Equatable {}

struct _ITextResolvedGradient<ColorValue> {
    let colors: [ColorValue]
    let locations: [CGFloat]
    let startPoint: CGPoint
    let endPoint: CGPoint
}

extension _ITextResolvedGradient: Equatable where ColorValue: Equatable {}

extension ITextLinearGradient {
    func _resolved(isRightToLeft: Bool) -> _ITextResolvedGradient<ColorValue>? {
        guard !stops.isEmpty else { return nil }

        let divisor = max(stops.count - 1, 1)
        let resolvedStops = stops.enumerated()
            .map { index, stop in
                let fallback = CGFloat(index) / CGFloat(divisor)
                let finiteLocation = stop.location.isFinite ? stop.location : fallback
                return (
                    index: index,
                    color: stop.color,
                    location: min(max(finiteLocation, 0), 1)
                )
            }
            .sorted { lhs, rhs in
                if lhs.location == rhs.location {
                    return lhs.index < rhs.index
                }
                return lhs.location < rhs.location
            }

        let start = startPoint._resolved(isRightToLeft: isRightToLeft)
        let end = endPoint._resolved(isRightToLeft: isRightToLeft)
        let fallbackStart = ITextGradientPoint.leading._resolved(
            isRightToLeft: isRightToLeft
        )!
        let fallbackEnd = ITextGradientPoint.trailing._resolved(
            isRightToLeft: isRightToLeft
        )!

        return _ITextResolvedGradient(
            colors: resolvedStops.map(\.color),
            locations: resolvedStops.map(\.location),
            startPoint: start ?? fallbackStart,
            endPoint: end ?? fallbackEnd
        )
    }
}

private extension ITextGradientPoint {
    func _resolved(isRightToLeft: Bool) -> CGPoint? {
        let leadingX: CGFloat = isRightToLeft ? 1 : 0
        let trailingX: CGFloat = isRightToLeft ? 0 : 1

        switch self {
        case .topLeading:
            return CGPoint(x: leadingX, y: 0)
        case .top:
            return CGPoint(x: 0.5, y: 0)
        case .topTrailing:
            return CGPoint(x: trailingX, y: 0)
        case .leading:
            return CGPoint(x: leadingX, y: 0.5)
        case .center:
            return CGPoint(x: 0.5, y: 0.5)
        case .trailing:
            return CGPoint(x: trailingX, y: 0.5)
        case .bottomLeading:
            return CGPoint(x: leadingX, y: 1)
        case .bottom:
            return CGPoint(x: 0.5, y: 1)
        case .bottomTrailing:
            return CGPoint(x: trailingX, y: 1)
        case .unit(let x, let y):
            guard x.isFinite, y.isFinite else { return nil }
            return CGPoint(
                x: min(max(x, 0), 1),
                y: min(max(y, 0), 1)
            )
        }
    }
}
