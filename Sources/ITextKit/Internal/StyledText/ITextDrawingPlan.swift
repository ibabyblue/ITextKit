import CoreGraphics
import CoreText
import UIKit

enum _ITextResolvedCGPaint {
    case solid(CGColor)
    case linearGradient(
        colors: [CGColor],
        locations: [CGFloat],
        startPoint: CGPoint,
        endPoint: CGPoint
    )
}

struct _ITextResolvedCGStroke {
    let paint: _ITextResolvedCGPaint
    let outwardWidth: CGFloat
}

struct _ITextResolvedCGStyle {
    let fill: _ITextResolvedCGPaint?
    let stroke: _ITextResolvedCGStroke?
}

struct _ITextDrawingPlan {
    let layout: _ITextLayoutResult
    let style: _ITextResolvedCGStyle
    let gradientBounds: CGRect
    let shadowColor: CGColor?
    let shadowOffset: CGSize
    let drawingOffset: CGPoint
    private let traitCollection: UITraitCollection

    init(
        layout: _ITextLayoutResult,
        style: ITextUIKitStyle,
        gradientBounds: CGRect,
        traitCollection: UITraitCollection,
        layoutDirection: UIUserInterfaceLayoutDirection,
        shadowColor: UIColor?,
        shadowOffset: CGSize,
        drawingOffset: CGPoint = .zero
    ) {
        self.layout = layout
        let resolvedStyle = Self.resolve(
            style,
            traits: traitCollection,
            isRightToLeft: layoutDirection == .rightToLeft
        )
        self.style = resolvedStyle
        let strokeWidth = resolvedStyle.stroke?.outwardWidth ?? 0
        self.gradientBounds = gradientBounds.insetBy(
            dx: -strokeWidth,
            dy: -strokeWidth
        )
        self.shadowColor = shadowColor?
            .resolvedColor(with: traitCollection)
            .cgColor
        self.shadowOffset = shadowOffset
        self.drawingOffset = drawingOffset
        self.traitCollection = traitCollection
    }

    func draw(in context: CGContext) {
        guard !layout.inkBounds.isNull else { return }
        context.saveGState()
        context.translateBy(x: drawingOffset.x, y: drawingOffset.y)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        if let shadowColor {
            context.setShadow(
                offset: shadowOffset,
                blur: 0,
                color: shadowColor
            )
        }

        if let stroke = style.stroke, stroke.outwardWidth > 0 {
            drawCombinedStroke(stroke, in: context)
        } else {
            drawNativeStrokes(in: context)
        }
        drawFill(in: context)
        drawDecorations(in: context)
        drawFallbackRuns(in: context)
        context.restoreGState()
    }

    private func drawCombinedStroke(
        _ stroke: _ITextResolvedCGStroke,
        in context: CGContext
    ) {
        let path = combinedGlyphPath()
        guard !path.isEmpty else { return }
        switch stroke.paint {
        case .solid(let color):
            context.addPath(path)
            context.setStrokeColor(color)
            context.setLineWidth(stroke.outwardWidth * 2)
            context.strokePath()
        case .linearGradient:
            context.saveGState()
            context.addPath(path)
            context.setLineWidth(stroke.outwardWidth * 2)
            context.replacePathWithStrokedPath()
            context.clip()
            draw(stroke.paint, in: context)
            context.restoreGState()
        }
    }

    private func drawNativeStrokes(in context: CGContext) {
        for glyph in layout.glyphs {
            guard let color = glyph.nativeStrokeColor,
                  glyph.nativeStrokeWidth != 0 else { continue }
            let resolvedWidth = abs(glyph.nativeStrokeWidth)
                * CTFontGetSize(glyph.font)
                / 100
            context.addPath(glyph.path)
            context.setStrokeColor(
                color.resolvedColor(with: traitCollection).cgColor
            )
            context.setLineWidth(resolvedWidth)
            context.strokePath()
        }
    }

    private func drawFill(in context: CGContext) {
        if let fill = style.fill {
            let path = combinedGlyphPath()
            guard !path.isEmpty else { return }
            switch fill {
            case .solid(let color):
                context.addPath(path)
                context.setFillColor(color)
                context.fillPath()
            case .linearGradient:
                context.saveGState()
                context.addPath(path)
                context.clip()
                draw(fill, in: context)
                context.restoreGState()
            }
            return
        }

        for glyph in layout.glyphs {
            context.addPath(glyph.path)
            context.setFillColor(
                glyph.foregroundColor
                    .resolvedColor(with: traitCollection)
                    .cgColor
            )
            context.fillPath()
        }
    }

    private func drawDecorations(in context: CGContext) {
        for decoration in layout.decorations {
            context.setFillColor(
                decoration.color
                    .resolvedColor(with: traitCollection)
                    .cgColor
            )
            context.fill(decoration.rect)
        }
    }

    private func drawFallbackRuns(in context: CGContext) {
        for fallback in layout.fallbackRuns {
            context.saveGState()
            context.translateBy(x: fallback.origin.x, y: fallback.origin.y)
            context.scaleBy(x: 1, y: -1)
            context.textPosition = .zero
            CTRunDraw(
                fallback.run,
                context,
                CFRange(location: 0, length: 0)
            )
            context.restoreGState()
        }
    }

    private func draw(_ paint: _ITextResolvedCGPaint, in context: CGContext) {
        guard case let .linearGradient(
            colors,
            locations,
            normalizedStart,
            normalizedEnd
        ) = paint,
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: locations
        ) else { return }
        let bounds = gradientBounds.isNull ? layout.inkBounds : gradientBounds
        let start = CGPoint(
            x: bounds.minX + bounds.width * normalizedStart.x,
            y: bounds.minY + bounds.height * normalizedStart.y
        )
        let end = CGPoint(
            x: bounds.minX + bounds.width * normalizedEnd.x,
            y: bounds.minY + bounds.height * normalizedEnd.y
        )
        context.drawLinearGradient(
            gradient,
            start: start,
            end: end,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    private func combinedGlyphPath() -> CGPath {
        let combined = CGMutablePath()
        for glyph in layout.glyphs {
            combined.addPath(glyph.path)
        }
        return combined
    }

    private static func resolve(
        _ style: ITextUIKitStyle,
        traits: UITraitCollection,
        isRightToLeft: Bool
    ) -> _ITextResolvedCGStyle {
        let resolved = style._resolved(isRightToLeft: isRightToLeft)
        return _ITextResolvedCGStyle(
            fill: resolved.fill.map { resolve($0, traits: traits) },
            stroke: resolved.stroke.map {
                _ITextResolvedCGStroke(
                    paint: resolve($0.paint, traits: traits),
                    outwardWidth: $0.outwardWidth
                )
            }
        )
    }

    private static func resolve(
        _ paint: _ITextResolvedPaint<UIColor>,
        traits: UITraitCollection
    ) -> _ITextResolvedCGPaint {
        switch paint {
        case .solid(let color):
            return .solid(color.resolvedColor(with: traits).cgColor)
        case .linearGradient(let gradient):
            return .linearGradient(
                colors: gradient.colors.map {
                    $0.resolvedColor(with: traits).cgColor
                },
                locations: gradient.locations,
                startPoint: gradient.startPoint,
                endPoint: gradient.endPoint
            )
        }
    }
}
