import ITextKit
import UIKit

final class UIKitTypewriterExamplesViewController: UIKitDemoDetailViewController {
    private let plain = ITextTypewriterView(text: "A plain typewriter grows as it reveals.")
    private let attributed = ITextTypewriterView(attributedText: UIKitTypewriterExamplesViewController.richText)
    private let styled = ITextTypewriterView(text: "Styled typewriter")
    private let wrapping = ITextTypewriterView(text: "This longer typewriter grows wider, wraps, and then grows taller.")
    private let emoji = ITextTypewriterView(text: "Rich 👨‍👩‍👧‍👦 typewriter")
    init() { super.init(topic: .typewriter); configureExamples() }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func configureExamples() {
        all.forEach { $0.numberOfLines = 0; $0.adjustsFontForContentSizeCategory = true }
        styled.font = .systemFont(ofSize: 22, weight: .bold); styled.textStyle = .init(fill: .linearGradient(.init(colors: [.systemPink, .systemOrange])), stroke: .init(paint: .solid(.systemBlue), width: 1))
        add("uikit.typewriter.plain", "Plain input", "Intrinsic width and height grow with the visible prefix.", "let view = ITextTypewriterView(text: \"A plain typewriter grows as it reveals.\")", plain)
        add("uikit.typewriter.attributed", "Attributed input", "NSAttributedString runs reveal on complete character boundaries.", "let view = ITextTypewriterView(attributedText: richText)", attributed)
        add("uikit.typewriter.styled", "Styled input", "textStyle composes vector fill and outline.", """
        let view = ITextTypewriterView(text: "Styled typewriter")
        view.textStyle = .init(
            fill: .linearGradient(.init(colors: [.systemPink, .systemOrange])),
            stroke: .init(paint: .solid(.systemBlue), width: 1)
        )
        """, styled)
        wrapping.widthAnchor.constraint(lessThanOrEqualToConstant: 280).isActive = true
        add("uikit.typewriter.wrapping", "Wrapping and growth", "A maximum width lets Auto Layout derive the changing intrinsic height.", "view.widthAnchor.constraint(lessThanOrEqualToConstant: 280).isActive = true", wrapping)
        add("uikit.typewriter.emoji", "Emoji stays whole", "The family emoji is one extended grapheme cluster.", "let view = ITextTypewriterView(text: \"Rich 👨‍👩‍👧‍👦 typewriter\")", emoji)
        add("uikit.typewriter.replay", "Replay", "Assign empty content, then the fresh value; no unsupported playback controls exist.", "view.text = \"\"\nview.text = message", replayButton())
    }
    private var all: [ITextTypewriterView] { [plain, attributed, styled, wrapping, emoji] }
    private func replayButton() -> UIButton { let button = UIButton(type: .system, primaryAction: UIAction(title: "Replay Typewriter") { [weak self] _ in guard let self else { return }; plain.text = ""; attributed.attributedText = NSAttributedString(); styled.text = ""; wrapping.text = ""; emoji.text = ""; plain.text = "A plain typewriter grows as it reveals."; attributed.attributedText = Self.richText; styled.text = "Styled typewriter"; wrapping.text = "This longer typewriter grows wider, wraps, and then grows taller."; emoji.text = "Rich 👨‍👩‍👧‍👦 typewriter" }); button.configuration = .bordered(); return button }
    private func add(_ id: String, _ title: String, _ summary: String, _ code: String, _ content: UIView) { addSection(snippet: .init(id: id, title: title, summary: summary, capabilities: [.plain, .attributed, .styled, .dynamicType], code: code), content: content) }
    private static let richText = NSAttributedString(string: "Rich attributed typewriter", attributes: [.font: UIFont.preferredFont(forTextStyle: .headline), .foregroundColor: UIColor.systemIndigo, .underlineStyle: NSUnderlineStyle.single.rawValue])
}
