import ITextKit
import UIKit

final class UIKitShimmerExamplesViewController: UIKitDemoDetailViewController {
    private let plain = ITextShimmerLabel(), attributed = ITextShimmerLabel(), styled = ITextShimmerLabel(), configured = ITextShimmerLabel(), intrinsic = ITextShimmerLabel()
    private let stateLabel = UILabel()
    init() { super.init(topic: .shimmer); configureExamples() }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func configureExamples() {
        plain.text = "Plain label shimmer"; plain.font = .preferredFont(forTextStyle: .headline)
        attributed.attributedText = Self.richText
        styled.text = "Styled shimmer"; styled.font = .systemFont(ofSize: 28, weight: .bold); styled.textStyle = .init(fill: .linearGradient(.init(colors: [.systemPink, .systemOrange])), stroke: .init(paint: .linearGradient(.init(colors: [.white, .systemYellow])), width: 2))
        configured.text = "Configured shimmer"; configured.configuration = .init(duration: 1.2, bandWidth: 0.2, intensity: 0.9, direction: .trailingToLeading); configured.highlightColor = .systemYellow
        intrinsic.text = "Intrinsic shimmer label"; intrinsic.font = .preferredFont(forTextStyle: .body)
        all.forEach { $0.isShimmering = true; $0.adjustsFontForContentSizeCategory = true }
        add("uikit.shimmer.plain", "Plain label", "UILabel-compatible plain content keeps native sizing.", "let label = ITextShimmerLabel(); label.text = \"Plain\"; label.isShimmering = true", plain)
        add("uikit.shimmer.attributed", "Attributed label", "Caller-owned attributes are copied and preserved.", "label.attributedText = richText", attributed)
        add("uikit.shimmer.styled", "Styled fill + stroke", "The highlight copy mirrors gradient fill and outline.", """
        let label = ITextShimmerLabel()
        label.textStyle = .init(
            fill: .linearGradient(.init(colors: [.systemPink, .systemOrange])),
            stroke: .init(paint: .linearGradient(.init(colors: [.white, .systemYellow])), width: 2)
        )
        label.isShimmering = true
        """, styled)
        add("uikit.shimmer.configuration", "Configuration", "Configure timing, band, intensity, direction, and highlightColor.", "label.configuration = .init(duration: 1.2, bandWidth: 0.2, intensity: 0.9, direction: .trailingToLeading)", configured)
        add("uikit.shimmer.intrinsic", "Intrinsic size", "The label remains its only layout and accessibility owner.", "// Use ITextShimmerLabel like UILabel; no overlay label is required.", intrinsic)
        add("uikit.shimmer.toggle", "Active state", "isShimmering requests or removes the decorative animation.", "label.isShimmering = isActive", toggleView())
    }
    private var all: [ITextShimmerLabel] { [plain, attributed, styled, configured, intrinsic] }
    private func toggleView() -> UIView { let toggle = UISwitch(); toggle.isOn = true; toggle.accessibilityLabel = "Shimmer active"; stateLabel.text = "Shimmer: On"; let action = UIAction { [weak self, weak toggle] _ in guard let self, let toggle else { return }; all.forEach { $0.isShimmering = toggle.isOn }; stateLabel.text = toggle.isOn ? "Shimmer: On" : "Shimmer: Off" }; toggle.addAction(action, for: .valueChanged); let stack = UIStackView(arrangedSubviews: [toggle, stateLabel]); stack.axis = .vertical; stack.alignment = .leading; stack.spacing = 8; return stack }
    private func add(_ id: String, _ title: String, _ summary: String, _ code: String, _ content: UIView) { addSection(snippet: .init(id: id, title: title, summary: summary, capabilities: [.plain, .attributed, .styled, .accessibility], code: code), content: content) }
    private static let richText = NSAttributedString(string: "Attributed shimmer", attributes: [.font: UIFont.preferredFont(forTextStyle: .headline), .foregroundColor: UIColor.systemIndigo, .underlineStyle: NSUnderlineStyle.single.rawValue])
}
