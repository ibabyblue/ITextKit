import Combine
import SwiftUI

/// A SwiftUI view that automatically rotates through plain or attributed text values.
///
/// The current text moves upward while fading out and the next text enters from below. The view's
/// ideal height follows the currently rendered text; while transitioning, both texts participate
/// in layout so the larger height remains available. Reduce Motion replaces movement with a
/// cross-fade while preserving automatic rotation.
@MainActor
public struct ITextRotator: View {
    /// The ordered localized attributed text supplied by the caller.
    private let attributedTexts: [AttributedString]

    /// Shared timing values.
    private let configuration: ITextRotatorConfiguration

    /// Caller-requested playback state.
    private let playbackState: ITextPlaybackState

    /// Action invoked after a new text finishes settling.
    private var onTextChange: ((Int, String) -> Void)?

    /// Long-lived timing and display-link ownership.
    @StateObject private var model: _ITextRotatorObservable

    /// Current system motion preference.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Current scene lifecycle phase.
    @Environment(\.scenePhase) private var scenePhase

    /// Creates an automatically rotating text view.
    ///
    /// - Parameters:
    ///   - texts: Ordered, already-localized plain strings. Empty input renders nothing and a
    ///     single value remains static.
    ///   - configuration: Rotation timing. Defaults to ``ITextRotatorConfiguration/default``.
    ///   - playbackState: Caller-requested playback state. Pausing freezes exact timing and
    ///     transition progress; stopping discards progress and keeps the last settled text.
    public init(
        texts: [String],
        configuration: ITextRotatorConfiguration = .default,
        playbackState: ITextPlaybackState = .playing
    ) {
        self.init(
            attributedTexts: texts.map(AttributedString.init),
            configuration: configuration,
            playbackState: playbackState
        )
    }

    /// Creates an automatically rotating attributed-text view.
    ///
    /// Inline attributes take precedence over view-level text modifiers. Empty input renders
    /// nothing and a single value remains static.
    ///
    /// - Parameters:
    ///   - attributedTexts: Ordered, already-localized attributed values.
    ///   - configuration: Rotation timing. Defaults to ``ITextRotatorConfiguration/default``.
    ///   - playbackState: Caller-requested playback state.
    public init(
        attributedTexts: [AttributedString],
        configuration: ITextRotatorConfiguration = .default,
        playbackState: ITextPlaybackState = .playing
    ) {
        self.attributedTexts = attributedTexts
        self.configuration = configuration
        self.playbackState = playbackState
        _model = StateObject(wrappedValue: _ITextRotatorObservable(
            attributedTexts: attributedTexts,
            configuration: configuration,
            playbackState: playbackState
        ))
    }

    /// The current and optional entering text rendered from deterministic transition progress.
    public var body: some View {
        let transition = _ITextRotatorTransitionPresentation(
            linearProgress: model.transitionProgress,
            reduceMotion: reduceMotion
        )

        ZStack(alignment: .topLeading) {
            if let currentText = model.currentAttributedText {
                Text(currentText)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(transition.outgoing.opacity)
                    .modifier(_ITextVerticalOffsetEffect(
                        factor: CGFloat(transition.outgoing.verticalOffsetFactor)
                    ))
            }

            if let nextText = model.nextAttributedText {
                Text(nextText)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(transition.incoming.opacity)
                    .modifier(_ITextVerticalOffsetEffect(
                        factor: CGFloat(transition.incoming.verticalOffsetFactor)
                    ))
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.currentPlainText)
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
        .onChange(of: attributedTexts) { value in
            model.updateAttributedTexts(value)
        }
        .onChange(of: configuration) { value in
            model.updateConfiguration(value)
        }
        .onChange(of: playbackState) { value in
            model.setPlaybackState(value)
        }
        .onReceive(model.settledTexts) { index, text in
            onTextChange?(index, text)
        }
    }

    /// Registers an action that runs after a new text finishes its transition.
    ///
    /// Initial display does not invoke the action. Pausing or stopping an in-flight transition
    /// also remains silent.
    ///
    /// - Parameter action: A main-actor closure receiving the settled index and text.
    /// - Returns: A copy of the view with the change action installed.
    public func onTextRotatorChange(
        _ action: @escaping @MainActor (Int, String) -> Void
    ) -> ITextRotator {
        var copy = self
        copy.onTextChange = action
        return copy
    }

    /// Synchronizes value-semantic SwiftUI inputs with the long-lived model.
    private func synchronizeModel() {
        model.updateAttributedTexts(attributedTexts)
        model.updateConfiguration(configuration)
        model.setPlaybackState(playbackState)
    }
}

/// Translates one text by a factor of its own current layout height.
private struct _ITextVerticalOffsetEffect: GeometryEffect {
    /// `-1...0` moves an outgoing value upward; `1...0` moves an incoming value upward.
    var factor: CGFloat

    /// Participates in SwiftUI transactions while still accepting display-link-driven progress.
    var animatableData: CGFloat {
        get { factor }
        set { factor = newValue }
    }

    /// Resolves the translation after SwiftUI has measured this exact text.
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: 0,
            y: factor * size.height
        ))
    }
}

/// Observable adapter between the shared rotator engine and SwiftUI.
@MainActor
private final class _ITextRotatorObservable: ObservableObject {
    /// Latest state published to the view.
    @Published private(set) var snapshot: _ITextRotatorSnapshot

    /// Emits the settled index and text to the currently rendered SwiftUI callback modifier.
    let settledTexts = PassthroughSubject<(Int, String), Never>()

    /// Framework-independent timing engine.
    private let engine: _ITextRotatorEngine

    /// Current renderable content, owned by the SwiftUI adapter rather than the timing engine.
    private var attributedTexts: [AttributedString]

    /// Display-link clock stopped whenever time cannot advance.
    private let displayLink = _ITextDisplayLinkDriver()

    /// Whether the SwiftUI view is currently in a hierarchy.
    private var isVisible = false

    /// Whether the containing scene is active.
    private var sceneIsActive = false

    /// Creates a SwiftUI rotator model.
    init(
        attributedTexts: [AttributedString],
        configuration: ITextRotatorConfiguration,
        playbackState: ITextPlaybackState
    ) {
        let engine = _ITextRotatorEngine(
            itemCount: attributedTexts.count,
            configuration: configuration.resolved,
            playbackState: playbackState
        )
        self.engine = engine
        self.attributedTexts = attributedTexts
        self.snapshot = engine.snapshot

        engine.onSnapshotChanged = { [weak self] snapshot in
            self?.snapshot = snapshot
            self?.reconcileDisplayLink()
        }
        engine.onItemSettled = { [weak self] index in
            guard let self, self.attributedTexts.indices.contains(index) else { return }
            self.settledTexts.send((index, String(self.attributedTexts[index].characters)))
        }
        displayLink.onFrame = { [weak self] elapsed in
            self?.engine.advance(by: elapsed)
        }
    }

    /// The last fully settled attributed text, or `nil` for empty input.
    var currentAttributedText: AttributedString? {
        guard attributedTexts.indices.contains(snapshot.currentIndex) else { return nil }
        return attributedTexts[snapshot.currentIndex]
    }

    /// The entering attributed text during a transition.
    var nextAttributedText: AttributedString? {
        guard let index = snapshot.nextIndex, attributedTexts.indices.contains(index) else {
            return nil
        }
        return attributedTexts[index]
    }

    /// Plain characters exposed as the single accessibility element.
    var currentPlainText: String {
        currentAttributedText.map { String($0.characters) } ?? ""
    }

    /// Linear transition progress projected by the shared renderer presentation.
    var transitionProgress: Double { snapshot.progress }

    /// Replaces attributed values and restarts at the first item for any content or style change.
    func updateAttributedTexts(_ attributedTexts: [AttributedString]) {
        guard attributedTexts != self.attributedTexts else { return }
        self.attributedTexts = attributedTexts
        engine.updateItemCount(attributedTexts.count)
        snapshot = engine.snapshot
        reconcileDisplayLink()
    }

    /// Replaces normalized timing values.
    func updateConfiguration(_ configuration: ITextRotatorConfiguration) {
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
