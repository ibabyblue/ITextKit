import CoreGraphics
import SwiftUI
import UIKit

/// A solid or linear-gradient paint used by styled text.
public enum ITextPaint<ColorValue> {
    case solid(ColorValue)
    case linearGradient(ITextLinearGradient<ColorValue>)
}

extension ITextPaint: Equatable where ColorValue: Equatable {}

/// An outward text outline and its paint.
public struct ITextStroke<ColorValue> {
    /// Solid or linear-gradient outline paint.
    public var paint: ITextPaint<ColorValue>

    /// Final visible thickness extending outside each glyph, in points.
    ///
    /// Rendering resolves finite values to `0...64`. Negative and non-finite
    /// values resolve to zero. Internally, a centered line width of twice this
    /// value is drawn before the fill covers its inner half.
    public var width: CGFloat

    public init(paint: ITextPaint<ColorValue>, width: CGFloat) {
        self.paint = paint
        self.width = width
    }
}

extension ITextStroke: Equatable where ColorValue: Equatable {}

/// View-wide fill and outline styling for rendered text.
public struct ITextStyle<ColorValue> {
    /// A replacement glyph fill, or `nil` to preserve attributed foregrounds.
    public var fill: ITextPaint<ColorValue>?

    /// An ITextKit point-based outline, or `nil` to add no such outline.
    public var stroke: ITextStroke<ColorValue>?

    public init(
        fill: ITextPaint<ColorValue>? = nil,
        stroke: ITextStroke<ColorValue>? = nil
    ) {
        self.fill = fill
        self.stroke = stroke
    }
}

extension ITextStyle: Equatable where ColorValue: Equatable {}

/// UIKit specialization retaining dynamic `UIColor` values until drawing.
public typealias ITextUIKitStyle = ITextStyle<UIColor>

/// SwiftUI specialization retaining dynamic `Color` values until adaptation.
public typealias ITextSwiftUIStyle = ITextStyle<Color>

enum _ITextResolvedPaint<ColorValue> {
    case solid(ColorValue)
    case linearGradient(_ITextResolvedGradient<ColorValue>)
}

extension _ITextResolvedPaint: Equatable where ColorValue: Equatable {}

struct _ITextResolvedStroke<ColorValue> {
    let paint: _ITextResolvedPaint<ColorValue>
    let outwardWidth: CGFloat

    var centeredLineWidth: CGFloat { outwardWidth * 2 }
}

extension _ITextResolvedStroke: Equatable where ColorValue: Equatable {}

struct _ITextResolvedStyle<ColorValue> {
    let fill: _ITextResolvedPaint<ColorValue>?
    let stroke: _ITextResolvedStroke<ColorValue>?
}

extension _ITextResolvedStyle: Equatable where ColorValue: Equatable {}

extension ITextLinearGradient {
    func _resolvedPaint(
        isRightToLeft: Bool
    ) -> _ITextResolvedPaint<ColorValue>? {
        guard let gradient = _resolved(isRightToLeft: isRightToLeft) else {
            return nil
        }
        guard let firstColor = gradient.colors.first else { return nil }
        guard gradient.colors.count > 1,
              gradient.startPoint != gradient.endPoint else {
            return .solid(firstColor)
        }
        return .linearGradient(gradient)
    }
}

extension ITextPaint {
    func _resolved(isRightToLeft: Bool) -> _ITextResolvedPaint<ColorValue>? {
        switch self {
        case .solid(let color):
            return .solid(color)
        case .linearGradient(let gradient):
            return gradient._resolvedPaint(isRightToLeft: isRightToLeft)
        }
    }
}

extension ITextStroke {
    var _resolved: _ITextResolvedStroke<ColorValue>? {
        _resolved(isRightToLeft: false)
    }

    func _resolved(
        isRightToLeft: Bool
    ) -> _ITextResolvedStroke<ColorValue>? {
        guard let paint = paint._resolved(isRightToLeft: isRightToLeft) else {
            return nil
        }
        let finiteWidth = width.isFinite ? width : 0
        let outwardWidth = min(max(finiteWidth, 0), 64)
        return _ITextResolvedStroke(
            paint: paint,
            outwardWidth: outwardWidth
        )
    }
}

extension ITextStyle {
    func _resolved(isRightToLeft: Bool) -> _ITextResolvedStyle<ColorValue> {
        _ITextResolvedStyle(
            fill: fill?._resolved(isRightToLeft: isRightToLeft),
            stroke: stroke?._resolved(isRightToLeft: isRightToLeft)
        )
    }
}
