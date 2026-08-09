import Combine
import SwiftUI

/// A SwiftUI view that moves one overflowing line of text in a seamless loop.
///
/// Text that fits remains static. Overflowing text waits at semantic leading, then two identical
/// copies move at a constant points-per-second speed. Reduce Motion renders one static,
/// tail-truncated accessibility element.
@MainActor
public struct ITextMarquee: View {
    /// The already-localized plain text supplied by the caller.
    private let text: String

    /// Shared marquee motion values.
    private let configuration: ITextMarqueeConfiguration

    /// Caller-requested playback state.
    private let playbackState: ITextPlaybackState

    /// Long-lived timing and display-link ownership.
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
        self.text = text
        self.configuration = configuration
        self.playbackState = playbackState
        _model = StateObject(wrappedValue: _ITextMarqueeObservable(
            text: text,
            configuration: configuration,
            playbackState: playbackState
        ))
    }

    /// Static fallback, hidden measurement, and optional repeated moving copies.
    public var body: some View {
        Text(text)
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
                    .offset(x: resolvedOffset)
                    .accessibilityHidden(true)
                }
            }
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
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
            .onChange(of: text) { value in
                model.updateText(value)
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
        Text(text)
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
        Text(text)
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
    private var resolvedOffset: CGFloat {
        layoutDirection == .rightToLeft ? model.snapshot.offset : -model.snapshot.offset
    }

    /// Synchronizes value-semantic SwiftUI inputs with the long-lived model.
    private func synchronizeModel() {
        model.updateText(text)
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

/// Observable adapter between the shared marquee engine and SwiftUI.
@MainActor
private final class _ITextMarqueeObservable: ObservableObject {
    /// Latest state published to the view.
    @Published private(set) var snapshot: _ITextMarqueeSnapshot

    /// Framework-independent marquee timing engine.
    private let engine: _ITextMarqueeEngine

    /// Display-link clock stopped whenever time cannot advance.
    private let displayLink = _ITextDisplayLinkDriver()

    /// Last text used to determine whether motion should restart.
    private var text: String

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
        text: String,
        configuration: ITextMarqueeConfiguration,
        playbackState: ITextPlaybackState
    ) {
        let engine = _ITextMarqueeEngine(
            configuration: configuration.resolved,
            playbackState: playbackState
        )
        self.engine = engine
        self.text = text
        self.snapshot = engine.snapshot

        engine.onSnapshotChanged = { [weak self] snapshot in
            self?.snapshot = snapshot
            self?.reconcileDisplayLink()
        }
        displayLink.onFrame = { [weak self] elapsed in
            self?.engine.advance(by: elapsed)
        }
    }

    /// Restarts when the displayed plain text changes.
    func updateText(_ text: String) {
        guard text != self.text else { return }
        self.text = text
        engine.restart()
        snapshot = engine.snapshot
        reconcileDisplayLink()
    }

    /// Replaces normalized marquee motion values.
    func updateConfiguration(_ configuration: ITextMarqueeConfiguration) {
        engine.updateConfiguration(configuration.resolved)
        snapshot = engine.snapshot
        reconcileDisplayLink()
    }

    /// Applies caller-requested playback state.
    func setPlaybackState(_ playbackState: ITextPlaybackState) {
        engine.setPlaybackState(playbackState)
        snapshot = engine.snapshot
        reconcileDisplayLink()
    }

    /// Applies the current Reduce Motion permission.
    func setMotionAllowed(_ isAllowed: Bool) {
        engine.setMotionAllowed(isAllowed)
        snapshot = engine.snapshot
        reconcileDisplayLink()
    }

    /// Updates full text width and recalculates overflow.
    func updateContentWidth(_ width: CGFloat) {
        contentWidth = width
        updateMetrics()
    }

    /// Updates clipping viewport width and recalculates overflow.
    func updateViewportWidth(_ width: CGFloat) {
        viewportWidth = width
        updateMetrics()
    }

    /// Restarts semantic motion when leading/trailing direction changes.
    func restartForLayoutDirectionChange() {
        engine.restart()
        snapshot = engine.snapshot
        reconcileDisplayLink()
    }

    /// Applies complete visibility state when the view appears or disappears.
    func setVisible(_ isVisible: Bool, sceneIsActive: Bool) {
        self.isVisible = isVisible
        self.sceneIsActive = sceneIsActive
        applyEnvironmentState()
    }

    /// Applies scene activity while retaining hierarchy visibility.
    func setSceneActive(_ isActive: Bool) {
        sceneIsActive = isActive
        applyEnvironmentState()
    }

    /// Projects measured widths into the shared engine.
    private func updateMetrics() {
        engine.updateMetrics(contentWidth: contentWidth, viewportWidth: viewportWidth)
        snapshot = engine.snapshot
        reconcileDisplayLink()
    }

    /// Projects SwiftUI visibility into the shared engine.
    private func applyEnvironmentState() {
        engine.setEnvironmentActive(isVisible && sceneIsActive)
        reconcileDisplayLink()
    }

    /// Runs the display link only while elapsed time can change state.
    private func reconcileDisplayLink() {
        if engine.shouldAdvance {
            displayLink.start()
        } else {
            displayLink.stop()
        }
    }
}
