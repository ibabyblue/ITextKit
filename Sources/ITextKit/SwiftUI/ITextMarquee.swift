import Combine
import QuartzCore
import SwiftUI

/// A SwiftUI view that moves one overflowing line of plain or attributed text in a seamless loop.
///
/// Text that fits remains static. Overflowing text waits at semantic leading, then two identical
/// copies move at a constant points-per-second speed. Reduce Motion renders one static,
/// tail-truncated accessibility element.
@MainActor
public struct ITextMarquee: View {
    /// The already-localized attributed text supplied by the caller.
    private let attributedText: AttributedString

    /// Shared marquee motion values.
    private let configuration: ITextMarqueeConfiguration

    /// Caller-requested playback state.
    private let playbackState: ITextPlaybackState
    private let styledContent: _ITextStyledEffectConfiguration?

    /// Long-lived timing and discrete animation ownership.
    @StateObject private var model: _ITextMarqueeObservable

    /// Current system motion preference.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Current semantic layout direction.
    @Environment(\.layoutDirection) private var layoutDirection

    /// Current scene lifecycle phase.
    @Environment(\.scenePhase) private var scenePhase

    /// Creates a seamless marquee for one line of text.
    ///
    /// - Parameters:
    ///   - text: An already-localized plain string.
    ///   - configuration: Speed, copy spacing, and initial delay.
    ///   - playbackState: Caller-requested playback state. Pausing freezes the exact offset;
    ///     stopping returns to semantic leading and discards progress.
    public init(
        text: String,
        configuration: ITextMarqueeConfiguration = .default,
        playbackState: ITextPlaybackState = .playing
    ) {
        self.init(
            attributedText: AttributedString(text),
            configuration: configuration,
            playbackState: playbackState
        )
    }

    /// Creates a seamless marquee for one line of attributed text.
    ///
    /// Inline attributes take precedence over view-level text modifiers. The caller should supply
    /// semantic single-line content; newline handling follows native one-line text rendering.
    ///
    /// - Parameters:
    ///   - attributedText: An already-localized attributed value.
    ///   - configuration: Speed, copy spacing, and initial delay.
    ///   - playbackState: Caller-requested playback state.
    public init(
        attributedText: AttributedString,
        configuration: ITextMarqueeConfiguration = .default,
        playbackState: ITextPlaybackState = .playing
    ) {
        self.attributedText = attributedText
        self.styledContent = nil
        self.configuration = configuration
        self.playbackState = playbackState
        _model = StateObject(wrappedValue: _ITextMarqueeObservable(
            attributedText: attributedText,
            configuration: configuration,
            playbackState: playbackState
        ))
    }

    public init(
        text: String,
        font: UIFont = .preferredFont(forTextStyle: .body),
        textStyle: ITextSwiftUIStyle,
        adjustsFontForContentSizeCategory: Bool = true,
        configuration: ITextMarqueeConfiguration = .default,
        playbackState: ITextPlaybackState = .playing
    ) {
        self.init(
            styledAttributedText: NSAttributedString(string: text),
            defaultFont: font,
            textStyle: textStyle,
            adjustsFontForContentSizeCategory: adjustsFontForContentSizeCategory,
            configuration: configuration,
            playbackState: playbackState
        )
    }

    public init(
        styledAttributedText: NSAttributedString,
        defaultFont: UIFont = .preferredFont(forTextStyle: .body),
        textStyle: ITextSwiftUIStyle,
        adjustsFontForContentSizeCategory: Bool = true,
        configuration: ITextMarqueeConfiguration = .default,
        playbackState: ITextPlaybackState = .playing
    ) {
        let snapshot = NSAttributedString(attributedString: styledAttributedText)
        let nativeValue = AttributedString(snapshot.string)
        self.attributedText = nativeValue
        self.configuration = configuration
        self.playbackState = playbackState
        self.styledContent = .init(
            values: [snapshot],
            defaultFont: defaultFont,
            style: textStyle,
            adjustsFont: adjustsFontForContentSizeCategory
        )
        _model = StateObject(wrappedValue: _ITextMarqueeObservable(
            attributedText: nativeValue,
            configuration: configuration,
            playbackState: playbackState
        ))
    }

    /// Static fallback, hidden measurement, and optional repeated moving copies.
    @ViewBuilder public var body: some View {
        if let styledContent {
            _ITextStyledMarqueeRepresentable(
                content: styledContent,
                configuration: configuration,
                playbackState: playbackState
            )
            .accessibilityLabel(styledContent.values[0].string)
        } else {
            nativeBody
        }
    }

    private var nativeBody: some View {
        return Text(attributedText)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(showsMovingCopies ? 0 : 1)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: _ITextMarqueeViewportWidthPreferenceKey.self,
                        value: geometry.size.width
                    )
                }
            }
            .overlay(alignment: .leading) {
                measurementText
            }
            .overlay(alignment: .leading) {
                if showsMovingCopies {
                    HStack(spacing: configuration.resolved.spacing) {
                        movingText
                        movingText
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: resolvedTargetOffset)
                    .animation(
                        model.transition.animation,
                        value: model.transition.generation
                    )
                    .accessibilityHidden(true)
                }
            }
            .clipped()
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(plainText)
            .onPreferenceChange(_ITextMarqueeContentWidthPreferenceKey.self) { width in
                model.updateContentWidth(width)
            }
            .onPreferenceChange(_ITextMarqueeViewportWidthPreferenceKey.self) { width in
                model.updateViewportWidth(width)
            }
            .onAppear {
                synchronizeModel()
                model.setVisible(true, sceneIsActive: scenePhase == .active)
            }
            .onDisappear {
                model.setVisible(false, sceneIsActive: false)
            }
            .onChange(of: scenePhase) { phase in
                model.setSceneActive(phase == .active)
            }
            .onChange(of: reduceMotion) { value in
                model.setMotionAllowed(!value)
            }
            .onChange(of: layoutDirection) { _ in
                model.restartForLayoutDirectionChange()
            }
            .onChange(of: attributedText) { value in
                model.updateAttributedText(value)
            }
            .onChange(of: configuration) { value in
                model.updateConfiguration(value)
            }
            .onChange(of: playbackState) { value in
                model.setPlaybackState(value)
            }
    }

    /// A hidden, unconstrained copy used only to measure full text width.
    private var measurementText: some View {
        Text(attributedText)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .hidden()
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: _ITextMarqueeContentWidthPreferenceKey.self,
                        value: geometry.size.width
                    )
                }
            }
            .accessibilityHidden(true)
    }

    /// One untruncated moving text copy.
    private var movingText: some View {
        Text(attributedText)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    /// Whether repeated copies should replace the static truncating text.
    private var showsMovingCopies: Bool {
        model.snapshot.isOverflowing
            && configuration.resolved.speed > 0
            && !reduceMotion
            && playbackState != .stopped
    }

    /// Signed physical offset resolved from semantic layout direction.
    private var resolvedTargetOffset: CGFloat {
        layoutDirection == .rightToLeft
            ? model.transition.targetOffset
            : -model.transition.targetOffset
    }

    /// Plain characters exposed as the single accessibility element.
    private var plainText: String {
        String(attributedText.characters)
    }

    /// Synchronizes value-semantic SwiftUI inputs with the long-lived model.
    private func synchronizeModel() {
        model.updateAttributedText(attributedText)
        model.updateConfiguration(configuration)
        model.setPlaybackState(playbackState)
        model.setMotionAllowed(!reduceMotion)
    }
}

/// Captures full untruncated text width without affecting parent layout.
private struct _ITextMarqueeContentWidthPreferenceKey: PreferenceKey {
    /// The latest measured width.
    static var defaultValue: CGFloat = 0

    /// Keeps the latest nonnegative measurement.
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue(), 0)
    }
}

/// Captures the clipping viewport width supplied by the parent layout.
private struct _ITextMarqueeViewportWidthPreferenceKey: PreferenceKey {
    /// The latest measured width.
    static var defaultValue: CGFloat = 0

    /// Keeps the latest nonnegative measurement.
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue(), 0)
    }
}

/// One discrete SwiftUI animation instruction for compositor-driven marquee travel.
struct _ITextSwiftUIMarqueeTransition: Equatable {
    /// Semantic travel target in points.
    let targetOffset: CGFloat

    /// Linear travel duration in seconds. Zero means an immediate static placement.
    let duration: TimeInterval

    /// Delay before this travel begins.
    let delay: TimeInterval

    /// Whether SwiftUI repeats the full seamless cycle forever.
    let repeats: Bool

    /// Stable value used to trigger exactly one SwiftUI animation update.
    let generation: UInt64

    /// Animation resolved from the discrete instruction.
    var animation: Animation? {
        guard duration > 0 else { return nil }
        let linear = Animation.linear(duration: duration)
        if repeats {
            return linear.repeatForever(autoreverses: false).delay(delay)
        }
        return linear.delay(delay)
    }
}

/// Snapshot and transition published atomically for one SwiftUI renderer update.
private struct _ITextSwiftUIMarqueePresentation {
    let snapshot: _ITextMarqueeSnapshot
    let transition: _ITextSwiftUIMarqueeTransition
}

/// Observable adapter between the shared marquee engine and SwiftUI.
@MainActor
final class _ITextMarqueeObservable: ObservableObject {
    /// Atomically published renderer state.
    @Published private var presentation: _ITextSwiftUIMarqueePresentation

    /// Latest state exposed to the view.
    var snapshot: _ITextMarqueeSnapshot {
        presentation.snapshot
    }

    /// Latest discrete animation instruction exposed to the view.
    var transition: _ITextSwiftUIMarqueeTransition {
        presentation.transition
    }

    /// Number of discrete renderer publications, exposed to regression tests.
    private(set) var _publicationGeneration: UInt64 = 0

    /// Framework-independent marquee timing engine.
    private let engine: _ITextMarqueeEngine

    /// Cancellable delay primitive used only for a reconstructed partial-cycle seam.
    private let sleeper: (TimeInterval) async throws -> Void

    /// Current one-shot seam task, if travel resumed from a partial cycle.
    private var seamTask: Task<Void, Never>?

    /// Invalidates obsolete seam completions after every discrete state change.
    private var seamGeneration: UInt64 = 0

    /// Monotonic transition identity consumed by SwiftUI's animation modifier.
    private var transitionGeneration: UInt64 = 0

    /// Last attributed value used to determine whether motion should restart.
    private var attributedText: AttributedString

    /// Latest measured content width.
    private var contentWidth: CGFloat = 0

    /// Latest measured viewport width.
    private var viewportWidth: CGFloat = 0

    /// Whether the SwiftUI view is currently in a hierarchy.
    private var isVisible = false

    /// Whether the containing scene is active.
    private var sceneIsActive = false

    /// Creates a SwiftUI marquee model.
    init(
        attributedText: AttributedString,
        configuration: ITextMarqueeConfiguration,
        playbackState: ITextPlaybackState,
        now: @escaping () -> CFTimeInterval = CACurrentMediaTime,
        sleeper: @escaping (TimeInterval) async throws -> Void = { duration in
            if duration > 0 {
                let nanoseconds = UInt64(duration * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
            } else {
                await Task.yield()
            }
        }
    ) {
        let engine = _ITextMarqueeEngine(
            configuration: configuration.resolved,
            playbackState: playbackState,
            now: now
        )
        self.engine = engine
        self.sleeper = sleeper
        self.attributedText = attributedText
        self.presentation = _ITextSwiftUIMarqueePresentation(
            snapshot: engine.snapshot,
            transition: _ITextSwiftUIMarqueeTransition(
                targetOffset: 0,
                duration: 0,
                delay: 0,
                repeats: false,
                generation: 0
            )
        )

        engine.onSnapshotChanged = { [weak self] snapshot in
            self?.reconcile(snapshot: snapshot)
        }
    }

    deinit {
        seamTask?.cancel()
    }

    /// Restarts for any displayed content or attribute change.
    func updateAttributedText(_ attributedText: AttributedString) {
        guard attributedText != self.attributedText else { return }
        self.attributedText = attributedText
        engine.restart()
    }

    /// Replaces normalized marquee motion values.
    func updateConfiguration(_ configuration: ITextMarqueeConfiguration) {
        engine.updateConfiguration(configuration.resolved)
    }

    /// Applies caller-requested playback state.
    func setPlaybackState(_ playbackState: ITextPlaybackState) {
        engine.setPlaybackState(playbackState)
    }

    /// Applies the current Reduce Motion permission.
    func setMotionAllowed(_ isAllowed: Bool) {
        engine.setMotionAllowed(isAllowed)
    }

    /// Updates full text width and recalculates overflow.
    func updateContentWidth(_ width: CGFloat) {
        guard width != contentWidth else { return }
        contentWidth = width
        updateMetrics()
    }

    /// Updates clipping viewport width and recalculates overflow.
    func updateViewportWidth(_ width: CGFloat) {
        guard width != viewportWidth else { return }
        viewportWidth = width
        updateMetrics()
    }

    /// Restarts semantic motion when leading/trailing direction changes.
    func restartForLayoutDirectionChange() {
        engine.restart()
    }

    /// Applies complete visibility state when the view appears or disappears.
    func setVisible(_ isVisible: Bool, sceneIsActive: Bool) {
        guard isVisible != self.isVisible || sceneIsActive != self.sceneIsActive else {
            return
        }
        self.isVisible = isVisible
        self.sceneIsActive = sceneIsActive
        applyEnvironmentState()
    }

    /// Applies scene activity while retaining hierarchy visibility.
    func setSceneActive(_ isActive: Bool) {
        guard isActive != sceneIsActive else { return }
        sceneIsActive = isActive
        applyEnvironmentState()
    }

    /// Projects measured widths into the shared engine.
    private func updateMetrics() {
        engine.updateMetrics(contentWidth: contentWidth, viewportWidth: viewportWidth)
    }

    /// Projects SwiftUI visibility into the shared engine.
    private func applyEnvironmentState() {
        engine.setEnvironmentActive(isVisible && sceneIsActive)
    }

    /// Publishes one static, repeating, or remaining-cycle renderer instruction.
    private func reconcile(snapshot: _ITextMarqueeSnapshot) {
        cancelSeamTask()
        guard let plan = engine.motionPlan else {
            publish(
                snapshot: snapshot,
                targetOffset: snapshot.offset,
                duration: 0,
                delay: 0,
                repeats: false
            )
            return
        }

        let seamTolerance: CGFloat = 0.5
        if plan.offset <= seamTolerance {
            publish(
                snapshot: snapshot,
                targetOffset: plan.cycleDistance,
                duration: TimeInterval(plan.cycleDistance / plan.speed),
                delay: plan.delay,
                repeats: true
            )
        } else {
            publish(
                snapshot: snapshot,
                targetOffset: plan.cycleDistance,
                duration: plan.remainingCycleDuration,
                delay: plan.delay,
                repeats: false
            )
            scheduleRepeatingCycle(after: plan.delay + plan.remainingCycleDuration, plan: plan)
        }
    }

    /// Cancels and invalidates any completion belonging to an older partial cycle.
    private func cancelSeamTask() {
        seamGeneration &+= 1
        seamTask?.cancel()
        seamTask = nil
    }

    /// Schedules the only non-frame-rate callback needed by native SwiftUI travel.
    private func scheduleRepeatingCycle(
        after duration: TimeInterval,
        plan: _ITextMarqueeMotionPlan
    ) {
        let generation = seamGeneration
        let sleeper = self.sleeper
        seamTask = Task { @MainActor [weak self] in
            do {
                try await sleeper(duration)
            } catch {
                return
            }
            guard let self, generation == seamGeneration else { return }
            publish(
                snapshot: engine.snapshot,
                targetOffset: 0,
                duration: 0,
                delay: 0,
                repeats: false
            )
            do {
                try await sleeper(0)
            } catch {
                return
            }
            guard generation == seamGeneration else { return }
            publish(
                snapshot: engine.snapshot,
                targetOffset: plan.cycleDistance,
                duration: TimeInterval(plan.cycleDistance / plan.speed),
                delay: 0,
                repeats: true
            )
            seamTask = nil
        }
    }

    /// Emits one transition identity while avoiding any frame-rate publication.
    private func publish(
        snapshot: _ITextMarqueeSnapshot,
        targetOffset: CGFloat,
        duration: TimeInterval,
        delay: TimeInterval,
        repeats: Bool
    ) {
        transitionGeneration &+= 1
        _publicationGeneration &+= 1
        presentation = _ITextSwiftUIMarqueePresentation(
            snapshot: snapshot,
            transition: _ITextSwiftUIMarqueeTransition(
                targetOffset: targetOffset,
                duration: duration,
                delay: delay,
                repeats: repeats,
                generation: transitionGeneration
            )
        )
    }
}
