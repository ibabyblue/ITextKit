import CoreGraphics
import CoreText
import Foundation
import UIKit

protocol _ITextGlyphPathProviding: AnyObject {
    func path(
        font: CTFont,
        glyph: CGGlyph,
        transform: CGAffineTransform,
        build: () -> CGPath?
    ) -> CGPath?
}

/// A bounded cache for immutable glyph outlines.
///
/// Missing outlines are cached too, preventing repeated CoreText path requests
/// for color glyphs. The cache owns no layout or rendered-string snapshots.
final class _ITextGlyphPathCache: NSObject, _ITextGlyphPathProviding {
    static let shared = _ITextGlyphPathCache(
        countLimit: 2_048,
        totalCostLimit: 8 * 1_024 * 1_024
    )

    let countLimit: Int
    let totalCostLimit: Int

    var entryCount: Int {
        lock.withLock { storedEntryCount }
    }

    var estimatedCost: Int {
        lock.withLock { storedEstimatedCost }
    }

    private let cache = NSCache<_ITextGlyphPathKey, _ITextCachedGlyphPath>()
    private let lock = NSRecursiveLock()
    private var storedEntryCount = 0
    private var storedEstimatedCost = 0
    private var memoryWarningObserver: NSObjectProtocol?

    init(countLimit: Int, totalCostLimit: Int) {
        self.countLimit = max(countLimit, 0)
        self.totalCostLimit = max(totalCostLimit, 0)
        super.init()

        cache.countLimit = self.countLimit
        cache.totalCostLimit = self.totalCostLimit
        cache.delegate = self
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.removeAllObjects()
        }
    }

    deinit {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
    }

    func path(
        font: CTFont,
        glyph: CGGlyph,
        transform: CGAffineTransform,
        build: () -> CGPath?
    ) -> CGPath? {
        lock.withLock {
            let key = _ITextGlyphPathKey(
                font: font,
                glyph: glyph,
                transform: transform
            )
            if let cached = cache.object(forKey: key) {
                return cached.path
            }

            let path = build()
            let cost = Self.cost(of: path)
            let value = _ITextCachedGlyphPath(path: path, cost: cost)
            storedEntryCount += 1
            storedEstimatedCost += cost
            cache.setObject(value, forKey: key, cost: cost)
            return path
        }
    }

    func removeAllObjects() {
        lock.withLock {
            cache.removeAllObjects()
            storedEntryCount = 0
            storedEstimatedCost = 0
        }
    }

    private static func cost(of path: CGPath?) -> Int {
        guard let path else { return 64 }
        let bounds = path.boundingBoxOfPath
        let estimate = max(
            64,
            Double(abs(bounds.width * bounds.height)) / 4
        )
        guard estimate.isFinite else { return 64 }
        return Int(min(estimate.rounded(.up), Double(Int.max)))
    }
}

extension _ITextGlyphPathCache: NSCacheDelegate {
    func cache(
        _ cache: NSCache<AnyObject, AnyObject>,
        willEvictObject object: Any
    ) {
        guard let value = object as? _ITextCachedGlyphPath else { return }
        lock.withLock {
            storedEntryCount = max(storedEntryCount - 1, 0)
            storedEstimatedCost = max(storedEstimatedCost - value.cost, 0)
        }
    }
}

private final class _ITextCachedGlyphPath: NSObject {
    private enum Storage {
        case path(CGPath)
        case missing
    }

    let cost: Int
    private let storage: Storage

    init(path: CGPath?, cost: Int) {
        self.cost = cost
        self.storage = path.map(Storage.path) ?? .missing
    }

    var path: CGPath? {
        switch storage {
        case .path(let path):
            return path
        case .missing:
            return nil
        }
    }
}

private final class _ITextGlyphPathKey: NSObject {
    private let signature: String

    init(font: CTFont, glyph: CGGlyph, transform: CGAffineTransform) {
        let name = CTFontCopyPostScriptName(font) as String
        let fontMatrix = CTFontGetMatrix(font)
        let variations = (CTFontCopyVariation(font) as NSDictionary?)?.description ?? ""
        let values: [CGFloat] = [
            CTFontGetSize(font),
            fontMatrix.a,
            fontMatrix.b,
            fontMatrix.c,
            fontMatrix.d,
            fontMatrix.tx,
            fontMatrix.ty,
            transform.a,
            transform.b,
            transform.c,
            transform.d,
            transform.tx,
            transform.ty,
        ]
        let scalarSignature = values
            .map { String(Double($0).bitPattern, radix: 16) }
            .joined(separator: ":")
        signature = [
            name,
            String(CTFontGetSymbolicTraits(font).rawValue),
            variations,
            String(glyph),
            scalarSignature,
        ].joined(separator: "|")
    }

    override var hash: Int { signature.hashValue }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? _ITextGlyphPathKey else { return false }
        return signature == other.signature
    }
}

private extension NSRecursiveLock {
    func withLock<Value>(_ body: () throws -> Value) rethrows -> Value {
        lock()
        defer { unlock() }
        return try body()
    }
}
