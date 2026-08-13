import QuartzCore
import UIKit

final class _ITextDrawingLayer: CALayer {
    private(set) var drawingGeneration: UInt64 = 0

    var plan: _ITextDrawingPlan? {
        didSet { setNeedsDisplay() }
    }

    override init() {
        super.init()
        isOpaque = false
        drawsAsynchronously = false
        actions = [
            "bounds": NSNull(),
            "position": NSNull(),
            "contents": NSNull(),
        ]
    }

    override init(layer: Any) {
        if let source = layer as? _ITextDrawingLayer {
            plan = source.plan
        }
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isOpaque = false
        drawsAsynchronously = false
    }

    override func draw(in context: CGContext) {
        drawingGeneration &+= 1
        plan?.draw(in: context)
    }
}
