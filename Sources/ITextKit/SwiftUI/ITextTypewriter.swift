import Combine
import SwiftUI

/// A SwiftUI view that reveals plain or attributed text one complete character at a time.
///
/// The view starts with no visual footprint. Its ideal width and height grow with the currently
/// visible prefix, using the width proposed by the caller for native wrapping. Reduce Motion shows
/// the complete value immediately.
@MainActor
public struct ITextTypewriter: View {
    /// The complete attributed value supplied by the caller.
    private let attributedText: AttributedString

    /// Shared reveal timing.
    private let configuration: ITextTypewriterConfiguration

    /// Long-lived timing, content boundaries, and display-link ownership.
    @StateObject private var model: _ITextTypewriterObservable

    /// Current system motion preference.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Current scene lifecycle phase.
    @Environment(\.scenePhase) private var scenePhase

    /// Creates a typewriter view for plain text.
    ///
    /// - Parameters:
    ///   - text: An already-localized plain string.
    ///   - configuration: Character speed and initial delay.
    public init(
        text: String,
        configuration: ITextTypewriterConfiguration = .default
    ) {
        self.init(
            attributedText: AttributedString(text),
            configuration: configuration
        )
    }

    /// Creates a typewriter view for attributed text.
    ///
    /// Inline attributes are preserved as their complete extended grapheme clusters become visible.
    ///
    /// - Parameters:
    ///   - attributedText: An already-localized attributed value.
    ///   - configuration: Character speed and initial delay.
    public init(
        attributedText: AttributedString,
        configuration: ITextTypewriterConfiguration = .default
    ) {
        self.attributedText = attributedText
        self.configuration = configuration
        _model = StateObject(wrappedValue: _ITextTypewriterObservable(
            attributedText: attributedText,
            configuration: configuration
        ))
    }

    /// The current attributed prefix, with a zero-size placeholder before the first character.
    public var body: some View {
        Group {
            if model.snapshot.revealedCount == 0 {
                Color.clear
                    .frame(width: 0, height: 0)
            } else {
                Text(model.visibleAttributedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(fullPlainText)
        .onAppear {
            synchronizeModel()
            model.setMotionAllowed(!reduceMotion)
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
        .onChange(of: attributedText) { value in
            model.updateAttributedText(value)
        }
        .onChange(of: configuration) { value in
            model.updateConfiguration(value)
        }
    }

    /// Plain characters exposed as one complete accessibility value from the start.
    private var fullPlainText: String {
        String(attributedText.characters)
    }

    /// Synchronizes value-semantic SwiftUI inputs with the long-lived model.
    private func synchronizeModel() {
        model.updateAttributedText(attributedText)
        model.updateConfiguration(configuration)
    }
}

/// Observable adapter between the independent typewriter engine and SwiftUI.
@MainActor
final class _ITextTypewriterObservable: ObservableObject {
    /// Latest renderable reveal state.
    @Published private(set) var snapshot: _ITextTypewriterSnapshot

    /// Complete caller content owned by this view identity.
    private var attributedText: AttributedString

    /// End index of each complete extended grapheme cluster.
    private var characterEndIndices: [AttributedString.Index]

    /// Framework-independent timing engine.
    private let engine: _ITextTypewriterEngine

    /// Display-link clock stopped whenever elapsed time cannot reveal content.
    private let displayLink = _ITextDisplayLinkDriver()

    /// Whether the SwiftUI view is currently in a hierarchy.
    private var isVisible = false

    /// Whether the containing scene is active.
    private var sceneIsActive = false

    /// Creates a SwiftUI typewriter model.
    init(
        attributedText: AttributedString,
        configuration: ITextTypewriterConfiguration
    ) {
        let indices = Self.makeCharacterEndIndices(for: attributedText)
        let engine = _ITextTypewriterEngine(
            unitCount: indices.count,
            configuration: configuration.resolved
        )
        self.attributedText = attributedText
        self.characterEndIndices = indices
        self.engine = engine
        self.snapshot = engine.snapshot

        engine.onSnapshotChanged = { [weak self] snapshot in
            self?.snapshot = snapshot
            self?.reconcileDisplayLink()
        }
        displayLink.onFrame = { [weak self] elapsed in
            self?.engine.advance(by: elapsed)
        }
    }

    /// The attributed prefix ending at a complete extended grapheme boundary.
    var visibleAttributedText: AttributedString {
        let count = min(snapshot.revealedCount, characterEndIndices.count)
        guard count > 0 else { return AttributedString() }
        let endIndex = characterEndIndices[count - 1]
        return AttributedString(attributedText[..<endIndex])
    }

    /// Replaces actual content changes and ignores equal SwiftUI value reconstruction.
    func updateAttributedText(_ attributedText: AttributedString) {
        guard attributedText != self.attributedText else { return }
        self.attributedText = attributedText
        characterEndIndices = Self.makeCharacterEndIndices(for: attributedText)
        engine.updateUnitCount(characterEndIndices.count)
        snapshot = engine.snapshot
        reconcileDisplayLink()
    }

    /// Replaces actual timing changes and restarts from an empty prefix.
    func updateConfiguration(_ configuration: ITextTypewriterConfiguration) {
        engine.updateConfiguration(configuration.resolved)
        snapshot = engine.snapshot
        reconcileDisplayLink()
    }

    /// Applies current Reduce Motion behavior.
    func setMotionAllowed(_ isAllowed: Bool) {
        engine.setMotionAllowed(isAllowed)
        snapshot = engine.snapshot
        reconcileDisplayLink()
    }

    /// Applies complete hierarchy and scene visibility.
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

    /// Projects SwiftUI visibility into the independent engine.
    private func applyEnvironmentState() {
        engine.setEnvironmentActive(isVisible && sceneIsActive)
        snapshot = engine.snapshot
        reconcileDisplayLink()
    }

    /// Runs frame delivery only while elapsed time can reveal another unit.
    private func reconcileDisplayLink() {
        if engine.shouldAdvance {
            displayLink.start()
        } else {
            displayLink.stop()
        }
    }

    /// Builds attributed-string indices without splitting extended grapheme clusters.
    private static func makeCharacterEndIndices(
        for attributedText: AttributedString
    ) -> [AttributedString.Index] {
        var result: [AttributedString.Index] = []
        var index = attributedText.startIndex
        while index != attributedText.endIndex {
            index = attributedText.characters.index(after: index)
            result.append(index)
        }
        return result
    }
}
