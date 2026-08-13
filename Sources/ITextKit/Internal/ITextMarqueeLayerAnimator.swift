import QuartzCore
import UIKit

/// Owns compositor-driven marquee travel for one fixed motion layer.
@MainActor
final class _ITextMarqueeLayerAnimator: NSObject, CAAnimationDelegate {
    /// Stable animation key used for replacement, cleanup, and regression inspection.
    static let animationKey = "ITextKit.marquee.travel"

    /// Layer whose two pre-rendered text copies move together.
    private weak var layer: CALayer?

    /// Invalidates completion from a partial cycle after any newer instruction.
    private var generation: UInt64 = 0

    /// Full cycle needed when a reconstructed partial cycle reaches its seam.
    private var pendingRepeatingPlan: _ITextMarqueeMotionPlan?

    /// Physical direction retained for partial-cycle completion.
    private var pendingDirection: UIUserInterfaceLayoutDirection = .leftToRight

    /// Whether the owned layer currently has a travel animation.
    var hasActiveTravelAnimation: Bool {
        layer?.animation(forKey: Self.animationKey) != nil
    }

    /// Whether Core Animation local time is currently frozen.
    var isPaused: Bool {
        layer?.speed == 0
    }

    /// Installs travel from the logical phase described by `plan`.
    func install(
        on layer: CALayer,
        plan: _ITextMarqueeMotionPlan,
        direction: UIUserInterfaceLayoutDirection
    ) {
        generation &+= 1
        self.layer = layer
        pendingDirection = direction
        normalizeTiming(on: layer)
        layer.removeAnimation(forKey: Self.animationKey)
        setModelTranslation(0, on: layer)

        // Discrete activation and plan retrieval can differ by a few microseconds. Treat a
        // subpixel phase as the seam so a fresh start uses the permanent repeating animation
        // instead of an imperceptibly short reconstructed partial cycle.
        let seamTolerance = 1 / max(layer.contentsScale, 1)
        let startsAtSeam = abs(plan.offset) <= seamTolerance
        let effectivePlan = startsAtSeam
            ? _ITextMarqueeMotionPlan(
                offset: 0,
                cycleDistance: plan.cycleDistance,
                speed: plan.speed,
                delay: plan.delay
            )
            : plan
        pendingRepeatingPlan = startsAtSeam
            ? nil
            : _ITextMarqueeMotionPlan(
                offset: 0,
                cycleDistance: plan.cycleDistance,
                speed: plan.speed,
                delay: 0
            )
        addAnimation(
            plan: effectivePlan,
            direction: direction,
            repeats: startsAtSeam,
            generation: generation
        )
    }

    /// Freezes the current presentation at the exact compositor-local time.
    func pause() {
        guard let layer, hasActiveTravelAnimation, layer.speed != 0 else { return }
        let pausedTime = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0
        layer.timeOffset = pausedTime
    }

    /// Continues an existing animation from its exact frozen local time.
    func resume() {
        guard let layer, hasActiveTravelAnimation, layer.speed == 0 else { return }
        let frozenTime = layer.timeOffset
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
        let timeSincePause = layer.convertTime(CACurrentMediaTime(), from: nil) - frozenTime
        layer.beginTime = timeSincePause
    }

    /// Removes travel resources and restores normal layer timing and leading placement.
    func stop() {
        generation &+= 1
        pendingRepeatingPlan = nil
        guard let layer else { return }
        layer.removeAnimation(forKey: Self.animationKey)
        normalizeTiming(on: layer)
        setModelTranslation(0, on: layer)
    }

    /// Shows a retained logical phase without scheduling continuous animation.
    func present(
        offset: CGFloat,
        direction: UIUserInterfaceLayoutDirection,
        on layer: CALayer
    ) {
        generation &+= 1
        pendingRepeatingPlan = nil
        self.layer = layer
        layer.removeAnimation(forKey: Self.animationKey)
        normalizeTiming(on: layer)
        let translation = direction == .rightToLeft ? offset : -offset
        setModelTranslation(translation, on: layer)
    }

    /// Converts a completed reconstructed partial cycle into the permanent repeating cycle.
    nonisolated func animationDidStop(_ animation: CAAnimation, finished flag: Bool) {
        guard flag, let rawGeneration = animation.value(forKey: "ITextKit.generation") as? NSNumber else {
            return
        }
        Task { @MainActor [weak self] in
            self?.finishPartialCycle(generation: rawGeneration.uint64Value)
        }
    }

    /// Installs the zero-offset repeating cycle if the completion is still current.
    private func finishPartialCycle(generation completedGeneration: UInt64) {
        guard completedGeneration == generation,
              let plan = pendingRepeatingPlan,
              layer != nil else {
            return
        }
        pendingRepeatingPlan = nil
        addAnimation(
            plan: plan,
            direction: pendingDirection,
            repeats: true,
            generation: generation
        )
    }

    /// Builds one compositor animation without changing layout or drawing state.
    private func addAnimation(
        plan: _ITextMarqueeMotionPlan,
        direction: UIUserInterfaceLayoutDirection,
        repeats: Bool,
        generation: UInt64
    ) {
        guard let layer, plan.speed > 0, plan.cycleDistance > 0 else { return }
        let sign: CGFloat = direction == .rightToLeft ? 1 : -1
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = sign * plan.offset
        animation.toValue = sign * plan.cycleDistance
        animation.duration = plan.remainingCycleDuration
        animation.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) + plan.delay
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.fillMode = .backwards
        animation.repeatCount = repeats ? .infinity : 0
        animation.isRemovedOnCompletion = false
        if !repeats {
            animation.delegate = self
            animation.setValue(NSNumber(value: generation), forKey: "ITextKit.generation")
        }
        layer.add(animation, forKey: Self.animationKey)
    }

    /// Restores the standard Core Animation local-time basis.
    private func normalizeTiming(on layer: CALayer) {
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
    }

    /// Changes only the layer model transform with implicit actions disabled.
    private func setModelTranslation(_ translation: CGFloat, on layer: CALayer) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.setAffineTransform(CGAffineTransform(translationX: translation, y: 0))
        CATransaction.commit()
    }
}
