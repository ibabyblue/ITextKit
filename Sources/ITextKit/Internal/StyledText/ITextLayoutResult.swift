import CoreGraphics
import CoreText
import UIKit

struct _ITextLayoutRequest {
    let attributedText: NSAttributedString
    let defaultFont: UIFont
    let defaultColor: UIColor
    let constrainedSize: CGSize
    let numberOfLines: Int
    let lineBreakMode: NSLineBreakMode
    let alignment: NSTextAlignment
    let baselineAdjustment: UIBaselineAdjustment
    let adjustsFontSizeToFitWidth: Bool
    let minimumScaleFactor: CGFloat
    let allowsTightening: Bool
    let layoutDirection: UIUserInterfaceLayoutDirection
    let displayScale: CGFloat
    let outwardStrokeWidth: CGFloat
}

struct _ITextGlyphRecord {
    let path: CGPath
    let font: CTFont
    let glyph: CGGlyph
    let position: CGPoint
    let stringRange: CFRange
    let foregroundColor: UIColor
    let nativeStrokeColor: UIColor?
    let nativeStrokeWidth: CGFloat
}

struct _ITextFallbackRun {
    let line: CTLine
    let run: CTRun
    let origin: CGPoint
    let stringRange: CFRange
}

struct _ITextDecorationRecord {
    enum Kind {
        case underline
        case strikethrough
    }

    let kind: Kind
    let rect: CGRect
    let color: UIColor
}

struct _ITextLayoutResult {
    let size: CGSize
    let typographicBounds: CGRect
    let inkBounds: CGRect
    let firstBaseline: CGFloat
    let lastBaseline: CGFloat
    let glyphs: [_ITextGlyphRecord]
    let fallbackRuns: [_ITextFallbackRun]
    let decorations: [_ITextDecorationRecord]
    let isTruncated: Bool
    let scaleFactor: CGFloat
    let layoutGeneration: UInt64

    static func empty(layoutGeneration: UInt64) -> _ITextLayoutResult {
        _ITextLayoutResult(
            size: .zero,
            typographicBounds: .null,
            inkBounds: .null,
            firstBaseline: 0,
            lastBaseline: 0,
            glyphs: [],
            fallbackRuns: [],
            decorations: [],
            isTruncated: false,
            scaleFactor: 1,
            layoutGeneration: layoutGeneration
        )
    }
}
