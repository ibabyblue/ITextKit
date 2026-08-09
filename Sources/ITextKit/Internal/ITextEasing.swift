import Foundation

/// Shared timing curves used by both framework renderers.
enum _ITextEasing {
    /// Resolves the standard cubic ease-in-out curve `(0.42, 0, 0.58, 1)`.
    ///
    /// The engine retains linear elapsed progress so pause and resume stay exact. Renderers apply
    /// this pure projection only when deriving opacity and position.
    static func easeInOut(_ progress: Double) -> Double {
        let target = min(max(progress, 0), 1)
        guard target > 0, target < 1 else { return target }

        var lower = 0.0
        var upper = 1.0
        for _ in 0..<14 {
            let parameter = (lower + upper) / 2
            if cubicBezier(parameter, control1: 0.42, control2: 0.58) < target {
                lower = parameter
            } else {
                upper = parameter
            }
        }

        let parameter = (lower + upper) / 2
        return cubicBezier(parameter, control1: 0, control2: 1)
    }

    /// Evaluates one cubic Bézier axis whose endpoints are zero and one.
    private static func cubicBezier(
        _ parameter: Double,
        control1: Double,
        control2: Double
    ) -> Double {
        let inverse = 1 - parameter
        return 3 * inverse * inverse * parameter * control1
            + 3 * inverse * parameter * parameter * control2
            + parameter * parameter * parameter
    }
}
