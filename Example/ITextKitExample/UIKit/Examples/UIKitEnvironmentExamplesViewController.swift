import ITextKit
import UIKit

final class UIKitEnvironmentExamplesViewController: UIKitDemoDetailViewController {
    init() { super.init(topic: .environment); configureExamples() }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func configureExamples() {
        add("uikit.environment.ltr", "Left to right", "A container supplies forced LTR while the text view inherits it.", "container.semanticContentAttribute = .forceLeftToRight", directionContainer(.forceLeftToRight, text: "Left-to-right semantic leading"))
        add("uikit.environment.rtl", "Right to left", "A container supplies forced RTL; its child remains unspecified.", """
        container.semanticContentAttribute = .forceRightToLeft
        marquee.semanticContentAttribute = .unspecified
        """, directionContainer(.forceRightToLeft, text: "مرحبا بالعالم من اليمين إلى اليسار"))
        add("uikit.environment.dynamicType", "Dynamic Type", "Preferred fonts opt into content-size-category changes.", """
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        """, dynamicTypeView())
        let status = UILabel(); status.text = "System Reduce Motion: \(UIAccessibility.isReduceMotionEnabled ? "On" : "Off")"; status.numberOfLines = 0
        add("uikit.environment.reduceMotion", "Reduce Motion", "Read the real system state; never toggle it from the demo.", "let enabled = UIAccessibility.isReduceMotionEnabled", status)
        let voiceOver = UILabel(); voiceOver.text = "Use Settings to enable VoiceOver and verify each effect announces one complete value."; voiceOver.numberOfLines = 0; voiceOver.isAccessibilityElement = true
        add("uikit.environment.voiceOver", "VoiceOver", "The component itself owns accessibility; private rendering copies stay hidden.", "label.isAccessibilityElement = true\nlabel.accessibilityLabel = localizedText", voiceOver)
    }
    private func directionContainer(_ direction: UISemanticContentAttribute, text: String) -> UIView { let container = UIView(); container.semanticContentAttribute = direction; let view = ITextMarqueeView(text: text, playbackState: .paused); view.semanticContentAttribute = .unspecified; view.translatesAutoresizingMaskIntoConstraints = false; container.addSubview(view); NSLayoutConstraint.activate([view.leadingAnchor.constraint(equalTo: container.leadingAnchor), view.trailingAnchor.constraint(equalTo: container.trailingAnchor), view.topAnchor.constraint(equalTo: container.topAnchor), view.bottomAnchor.constraint(equalTo: container.bottomAnchor)]); return container }
    private func dynamicTypeView() -> UIView { let first = UILabel(), second = UILabel(); first.text = "Body preferred text"; first.font = .preferredFont(forTextStyle: .body); second.text = "Title preferred text"; second.font = .preferredFont(forTextStyle: .title2); [first, second].forEach { $0.adjustsFontForContentSizeCategory = true }; let stack = UIStackView(arrangedSubviews: [first, second]); stack.axis = .vertical; stack.spacing = 8; return stack }
    private func add(_ id: String, _ title: String, _ summary: String, _ code: String, _ content: UIView) { addSection(snippet: .init(id: id, title: title, summary: summary, capabilities: [.rtl, .dynamicType, .accessibility], code: code), content: content) }
}
