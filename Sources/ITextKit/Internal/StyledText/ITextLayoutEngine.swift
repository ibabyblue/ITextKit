import CoreGraphics
import CoreText
import UIKit

struct _ITextLayoutEngine {
    private struct LineRecord {
        let line: CTLine
        let origin: CGPoint
        let ascent: CGFloat
        let descent: CGFloat
        let leading: CGFloat
        let width: CGFloat
    }

    private static let generationLock = NSLock()
    private static var nextGeneration: UInt64 = 0

    private let pathProvider: _ITextGlyphPathProviding

    init(pathProvider: _ITextGlyphPathProviding = _ITextGlyphPathCache.shared) {
        self.pathProvider = pathProvider
    }

    func layout(_ request: _ITextLayoutRequest) -> _ITextLayoutResult {
        let generation = Self.makeGeneration()
        guard request.attributedText.length > 0 else {
            return .empty(layoutGeneration: generation)
        }

        let stroke = Self.normalizedStroke(request.outwardStrokeWidth)
        let strokeExpansion = stroke * 2
        let availableWidth = Self.available(
            request.constrainedSize.width,
            subtracting: strokeExpansion
        )
        let availableHeight = Self.available(
            request.constrainedSize.height,
            subtracting: strokeExpansion
        )
        guard availableWidth > 0, availableHeight > 0 else {
            return .empty(layoutGeneration: generation)
        }

        let content = _ITextAttributedContent(
            source: request.attributedText,
            defaultFont: request.defaultFont,
            defaultColor: request.defaultColor
        ).value
        let scaleFactor = fittedScale(
            for: content,
            request: request,
            availableWidth: availableWidth
        )
        let scaledContent = Self.scaled(content, by: scaleFactor)
        let construction = makeLines(
            for: scaledContent,
            request: request,
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            stroke: stroke
        )
        guard !construction.lines.isEmpty else {
            return .empty(layoutGeneration: generation)
        }

        var glyphRecords: [_ITextGlyphRecord] = []
        var fallbackRuns: [_ITextFallbackRun] = []
        var decorations: [_ITextDecorationRecord] = []
        var inkBounds = CGRect.null
        var typographicBounds = CGRect.null

        for lineRecord in construction.lines {
            let lineRect = CGRect(
                x: lineRecord.origin.x,
                y: lineRecord.origin.y - lineRecord.ascent,
                width: lineRecord.width,
                height: lineRecord.ascent + lineRecord.descent
            )
            typographicBounds = typographicBounds.union(lineRect)
            extract(
                lineRecord,
                defaultColor: request.defaultColor,
                glyphRecords: &glyphRecords,
                fallbackRuns: &fallbackRuns,
                decorations: &decorations,
                inkBounds: &inkBounds
            )
        }

        if inkBounds.isNull {
            inkBounds = typographicBounds
        }
        let contentWidth = max(
            construction.lines.map(\.width).max() ?? 0,
            0
        )
        let contentHeight = max(
            (construction.lines.last?.origin.y ?? 0)
                + (construction.lines.last?.descent ?? 0)
                - stroke,
            0
        )
        let alignedWidth = Self.alignmentNeedsContainerWidth(
            request.alignment,
            direction: request.layoutDirection
        ) ? availableWidth : contentWidth
        let rawSize = CGSize(
            width: min(alignedWidth + strokeExpansion, request.constrainedSize.width),
            height: min(contentHeight + strokeExpansion, request.constrainedSize.height)
        )
        let size = CGSize(
            width: Self.roundUp(rawSize.width, scale: request.displayScale),
            height: Self.roundUp(rawSize.height, scale: request.displayScale)
        )

        return _ITextLayoutResult(
            size: size,
            typographicBounds: Self.deviceBounds(
                typographicBounds,
                scale: request.displayScale
            ),
            inkBounds: Self.deviceBounds(inkBounds, scale: request.displayScale),
            firstBaseline: construction.lines.first?.origin.y ?? 0,
            lastBaseline: construction.lines.last?.origin.y ?? 0,
            glyphs: glyphRecords,
            fallbackRuns: fallbackRuns,
            decorations: decorations,
            isTruncated: construction.isTruncated,
            scaleFactor: scaleFactor,
            layoutGeneration: generation
        )
    }

    private func fittedScale(
        for content: NSAttributedString,
        request: _ITextLayoutRequest,
        availableWidth: CGFloat
    ) -> CGFloat {
        guard request.adjustsFontSizeToFitWidth,
              request.numberOfLines == 1,
              availableWidth.isFinite else {
            return 1
        }
        let line = CTLineCreateWithAttributedString(content)
        let naturalWidth = CGFloat(CTLineGetTypographicBounds(
            line,
            nil,
            nil,
            nil
        ))
        guard naturalWidth > availableWidth, naturalWidth > 0 else { return 1 }
        let minimum = min(max(request.minimumScaleFactor, 0), 1)
        return max(minimum, availableWidth / naturalWidth)
    }

    private func makeLines(
        for content: NSAttributedString,
        request: _ITextLayoutRequest,
        availableWidth: CGFloat,
        availableHeight: CGFloat,
        stroke: CGFloat
    ) -> (lines: [LineRecord], isTruncated: Bool) {
        let typesetter = CTTypesetterCreateWithAttributedString(content)
        let length = content.length
        let maximumLines = request.numberOfLines > 0
            ? request.numberOfLines
            : Int.max
        var records: [LineRecord] = []
        var location = 0
        var baseline = stroke
        var truncated = false

        while location < length, records.count < maximumLines {
            let isLastAllowedLine = records.count + 1 == maximumLines
            let remaining = length - location
            let suggested: Int
            if maximumLines == 1 || Self.isTruncating(request.lineBreakMode) {
                suggested = remaining
            } else if request.lineBreakMode == .byCharWrapping {
                suggested = CTTypesetterSuggestClusterBreak(
                    typesetter,
                    location,
                    Double(availableWidth)
                )
            } else {
                suggested = CTTypesetterSuggestLineBreak(
                    typesetter,
                    location,
                    Double(availableWidth)
                )
            }
            let safeLength = min(max(suggested, 1), remaining)
            let shouldUseRemainder = isLastAllowedLine && safeLength < remaining
            let sourceLength = shouldUseRemainder ? remaining : safeLength
            let sourceLine = CTTypesetterCreateLine(
                typesetter,
                CFRange(location: location, length: sourceLength)
            )
            let sourceWidth = CGFloat(CTLineGetTypographicBounds(
                sourceLine,
                nil,
                nil,
                nil
            ))
            let needsTruncation = sourceWidth > availableWidth || shouldUseRemainder
            let line: CTLine
            if needsTruncation, let truncationType = Self.truncationType(
                request.lineBreakMode,
                forcedTail: shouldUseRemainder
            ) {
                let token = Self.truncationToken(
                    for: content,
                    index: Self.tokenAttributeIndex(
                        location: location,
                        length: sourceLength,
                        truncationType: truncationType
                    )
                )
                line = CTLineCreateTruncatedLine(
                    sourceLine,
                    Double(availableWidth),
                    truncationType,
                    token
                ) ?? sourceLine
                truncated = true
            } else {
                line = sourceLine
                truncated = truncated || (needsTruncation && maximumLines == 1)
            }

            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            let width = CGFloat(CTLineGetTypographicBounds(
                line,
                &ascent,
                &descent,
                &leading
            ))
            if records.isEmpty {
                baseline += ascent
            } else {
                let previous = records[records.count - 1]
                baseline = previous.origin.y
                    + previous.descent
                    + max(previous.leading, 0)
                    + ascent
            }
            if baseline + descent - stroke > availableHeight {
                truncated = true
                break
            }
            let x = Self.lineOriginX(
                line,
                width: width,
                availableWidth: availableWidth,
                alignment: request.alignment,
                direction: request.layoutDirection
            ) + stroke
            records.append(LineRecord(
                line: line,
                origin: CGPoint(x: x, y: baseline),
                ascent: ascent,
                descent: descent,
                leading: leading,
                width: min(width, availableWidth),
            ))
            location += safeLength
            if maximumLines == 1 || Self.isTruncating(request.lineBreakMode) {
                if location < length || sourceWidth > availableWidth {
                    truncated = true
                }
                break
            }
        }
        if location < length {
            truncated = true
        }
        return (records, truncated)
    }

    private func extract(
        _ lineRecord: LineRecord,
        defaultColor: UIColor,
        glyphRecords: inout [_ITextGlyphRecord],
        fallbackRuns: inout [_ITextFallbackRun],
        decorations: inout [_ITextDecorationRecord],
        inkBounds: inout CGRect
    ) {
        let runs = CTLineGetGlyphRuns(lineRecord.line) as NSArray
        for case let run as CTRun in runs {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            var indices = [CFIndex](repeating: 0, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            CTRunGetStringIndices(run, CFRange(location: 0, length: 0), &indices)

            let attributes = CTRunGetAttributes(run) as NSDictionary
            let font = Self.font(from: attributes)
            let foreground = Self.color(
                in: attributes,
                key: NSAttributedString.Key.foregroundColor.rawValue,
                fallback: defaultColor
            )
            let nativeStrokeColor = Self.optionalColor(
                in: attributes,
                key: NSAttributedString.Key.strokeColor.rawValue
            )
            let nativeStrokeWidth = Self.number(
                in: attributes,
                key: NSAttributedString.Key.strokeWidth.rawValue
            )
            let textMatrix = CTRunGetTextMatrix(run)
            var paths: [CGPath?] = []
            paths.reserveCapacity(count)
            for glyph in glyphs {
                let path = pathProvider.path(
                    font: font,
                    glyph: glyph,
                    transform: textMatrix
                ) {
                    var transform = textMatrix
                    return CTFontCreatePathForGlyph(font, glyph, &transform)
                }
                paths.append(path)
            }

            let isColorRun = CTFontGetSymbolicTraits(font)
                .contains(.traitColorGlyphs)
            let hasOutline = zip(glyphs, paths).contains { glyph, path in
                glyph != 0 && path != nil
            }
            let runRange = CTRunGetStringRange(run)
            if isColorRun || !hasOutline {
                fallbackRuns.append(_ITextFallbackRun(
                    line: lineRecord.line,
                    run: run,
                    origin: lineRecord.origin,
                    stringRange: runRange
                ))
                let runBounds = Self.runBounds(
                    run,
                    positions: positions,
                    lineOrigin: lineRecord.origin
                )
                inkBounds = inkBounds.union(runBounds)
            } else {
                for index in paths.indices {
                    guard let path = paths[index] else { continue }
                    let placed = Self.place(
                        path,
                        at: positions[index],
                        lineOrigin: lineRecord.origin
                    )
                    let start = indices[index]
                    let end = index + 1 < indices.count
                        ? indices[index + 1]
                        : runRange.location + runRange.length
                    glyphRecords.append(_ITextGlyphRecord(
                        path: placed,
                        font: font,
                        glyph: glyphs[index],
                        position: positions[index],
                        stringRange: CFRange(
                            location: start,
                            length: max(end - start, 0)
                        ),
                        foregroundColor: foreground,
                        nativeStrokeColor: nativeStrokeColor,
                        nativeStrokeWidth: nativeStrokeWidth
                    ))
                    inkBounds = inkBounds.union(placed.boundingBoxOfPath)
                }
            }
            appendDecorations(
                for: run,
                attributes: attributes,
                font: font,
                foreground: foreground,
                lineOrigin: lineRecord.origin,
                positions: positions,
                to: &decorations,
                inkBounds: &inkBounds
            )
        }
    }

    private func appendDecorations(
        for run: CTRun,
        attributes: NSDictionary,
        font: CTFont,
        foreground: UIColor,
        lineOrigin: CGPoint,
        positions: [CGPoint],
        to records: inout [_ITextDecorationRecord],
        inkBounds: inout CGRect
    ) {
        let width = CGFloat(CTRunGetTypographicBounds(
            run,
            CFRange(location: 0, length: 0),
            nil,
            nil,
            nil
        ))
        let x = lineOrigin.x + (positions.first?.x ?? 0)
        let thickness = max(CTFontGetUnderlineThickness(font), 1 / 3)
        let underlineStyle = Self.number(
            in: attributes,
            key: NSAttributedString.Key.underlineStyle.rawValue
        )
        if Int(underlineStyle) != 0 {
            let color = Self.optionalColor(
                in: attributes,
                key: NSAttributedString.Key.underlineColor.rawValue
            ) ?? foreground
            let rect = CGRect(
                x: x,
                y: lineOrigin.y - CTFontGetUnderlinePosition(font),
                width: width,
                height: thickness
            )
            records.append(.init(kind: .underline, rect: rect, color: color))
            inkBounds = inkBounds.union(rect)
        }
        let strikethroughStyle = Self.number(
            in: attributes,
            key: NSAttributedString.Key.strikethroughStyle.rawValue
        )
        if Int(strikethroughStyle) != 0 {
            let color = Self.optionalColor(
                in: attributes,
                key: NSAttributedString.Key.strikethroughColor.rawValue
            ) ?? foreground
            let rect = CGRect(
                x: x,
                y: lineOrigin.y - CTFontGetXHeight(font) / 2,
                width: width,
                height: thickness
            )
            records.append(.init(
                kind: .strikethrough,
                rect: rect,
                color: color
            ))
            inkBounds = inkBounds.union(rect)
        }
    }

    private static func scaled(
        _ content: NSAttributedString,
        by scale: CGFloat
    ) -> NSAttributedString {
        guard scale < 1 else { return content }
        let mutable = NSMutableAttributedString(attributedString: content)
        let range = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttributes(in: range) { attributes, runRange, _ in
            if let font = attributes[.font] as? UIFont {
                mutable.addAttribute(
                    .font,
                    value: UIFont(
                        descriptor: font.fontDescriptor,
                        size: font.pointSize * scale
                    ),
                    range: runRange
                )
            } else if let font = attributes[
                NSAttributedString.Key(kCTFontAttributeName as String)
            ] {
                let ctFont = font as! CTFont
                mutable.addAttribute(
                    NSAttributedString.Key(kCTFontAttributeName as String),
                    value: CTFontCreateCopyWithAttributes(
                        ctFont,
                        CTFontGetSize(ctFont) * scale,
                        nil,
                        nil
                    ),
                    range: runRange
                )
            }
            if let kern = attributes[.kern] as? NSNumber {
                mutable.addAttribute(
                    .kern,
                    value: CGFloat(truncating: kern) * scale,
                    range: runRange
                )
            }
            if let baseline = attributes[.baselineOffset] as? NSNumber {
                mutable.addAttribute(
                    .baselineOffset,
                    value: CGFloat(truncating: baseline) * scale,
                    range: runRange
                )
            }
        }
        return mutable
    }

    private static func truncationToken(
        for content: NSAttributedString,
        index: Int
    ) -> CTLine {
        let safeIndex = min(max(index, 0), max(content.length - 1, 0))
        let attributes = content.attributes(at: safeIndex, effectiveRange: nil)
        return CTLineCreateWithAttributedString(NSAttributedString(
            string: "…",
            attributes: attributes
        ))
    }

    private static func tokenAttributeIndex(
        location: Int,
        length: Int,
        truncationType: CTLineTruncationType
    ) -> Int {
        switch truncationType {
        case .start:
            return location
        case .middle:
            return location + length / 2
        default:
            return location + max(length - 1, 0)
        }
    }

    private static func truncationType(
        _ mode: NSLineBreakMode,
        forcedTail: Bool
    ) -> CTLineTruncationType? {
        if forcedTail { return .end }
        switch mode {
        case .byTruncatingHead:
            return .start
        case .byTruncatingMiddle:
            return .middle
        case .byTruncatingTail:
            return .end
        case .byClipping:
            return nil
        default:
            return .end
        }
    }

    private static func isTruncating(_ mode: NSLineBreakMode) -> Bool {
        switch mode {
        case .byTruncatingHead, .byTruncatingMiddle, .byTruncatingTail:
            return true
        default:
            return false
        }
    }

    private static func lineOriginX(
        _ line: CTLine,
        width: CGFloat,
        availableWidth: CGFloat,
        alignment: NSTextAlignment,
        direction: UIUserInterfaceLayoutDirection
    ) -> CGFloat {
        let flush: CGFloat
        switch alignment {
        case .center:
            flush = 0.5
        case .right:
            flush = 1
        case .natural:
            flush = direction == .rightToLeft ? 1 : 0
        default:
            flush = 0
        }
        guard flush > 0 else { return 0 }
        let offset = CGFloat(CTLineGetPenOffsetForFlush(
            line,
            Double(flush),
            Double(availableWidth)
        ))
        return offset.isFinite ? max(offset, 0) : max((availableWidth - width) * flush, 0)
    }

    private static func alignmentNeedsContainerWidth(
        _ alignment: NSTextAlignment,
        direction: UIUserInterfaceLayoutDirection
    ) -> Bool {
        alignment == .center
            || alignment == .right
            || (alignment == .natural && direction == .rightToLeft)
    }

    private static func place(
        _ path: CGPath,
        at position: CGPoint,
        lineOrigin: CGPoint
    ) -> CGPath {
        var transform = CGAffineTransform(
            a: 1,
            b: 0,
            c: 0,
            d: -1,
            tx: lineOrigin.x + position.x,
            ty: lineOrigin.y - position.y
        )
        return path.copy(using: &transform) ?? path
    }

    private static func runBounds(
        _ run: CTRun,
        positions: [CGPoint],
        lineOrigin: CGPoint
    ) -> CGRect {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CGFloat(CTRunGetTypographicBounds(
            run,
            CFRange(location: 0, length: 0),
            &ascent,
            &descent,
            nil
        ))
        return CGRect(
            x: lineOrigin.x + (positions.first?.x ?? 0),
            y: lineOrigin.y - ascent,
            width: width,
            height: ascent + descent
        )
    }

    private static func font(from attributes: NSDictionary) -> CTFont {
        let rawKey = kCTFontAttributeName as String
        if let font = attributes[rawKey] {
            return font as! CTFont
        }
        if let font = attributes[NSAttributedString.Key.font.rawValue] as? UIFont {
            return font as CTFont
        }
        return CTFontCreateWithName("Helvetica" as CFString, 12, nil)
    }

    private static func optionalColor(
        in attributes: NSDictionary,
        key: String
    ) -> UIColor? {
        if let color = attributes[key] as? UIColor {
            return color
        }
        if let color = attributes[key] {
            return UIColor(cgColor: color as! CGColor)
        }
        return nil
    }

    private static func color(
        in attributes: NSDictionary,
        key: String,
        fallback: UIColor
    ) -> UIColor {
        optionalColor(in: attributes, key: key) ?? fallback
    }

    private static func number(
        in attributes: NSDictionary,
        key: String
    ) -> CGFloat {
        guard let number = attributes[key] as? NSNumber else { return 0 }
        return CGFloat(truncating: number)
    }

    private static func normalizedStroke(_ width: CGFloat) -> CGFloat {
        guard width.isFinite else { return 0 }
        return min(max(width, 0), 64)
    }

    private static func available(
        _ constraint: CGFloat,
        subtracting amount: CGFloat
    ) -> CGFloat {
        guard constraint.isFinite else { return CGFloat.greatestFiniteMagnitude }
        return max(constraint - amount, 0)
    }

    private static func roundUp(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        let validScale = scale.isFinite && scale > 0 ? scale : 1
        return ceil(max(value, 0) * validScale) / validScale
    }

    private static func deviceBounds(_ rect: CGRect, scale: CGFloat) -> CGRect {
        guard !rect.isNull, !rect.isInfinite else { return rect }
        let validScale = scale.isFinite && scale > 0 ? scale : 1
        let minX = floor(rect.minX * validScale) / validScale
        let minY = floor(rect.minY * validScale) / validScale
        let maxX = ceil(rect.maxX * validScale) / validScale
        let maxY = ceil(rect.maxY * validScale) / validScale
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    private static func makeGeneration() -> UInt64 {
        generationLock.lock()
        defer { generationLock.unlock() }
        nextGeneration &+= 1
        return nextGeneration
    }
}
