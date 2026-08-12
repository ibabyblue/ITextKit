import QuartzCore
import UIKit

final class _ITextDrawingLayer: CALayer {
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
        plan?.draw(in: context)
    }
}
