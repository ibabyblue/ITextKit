import ITextKit
import UIKit

final class UIKitMarqueeExamplesViewController: UIKitDemoDetailViewController {
    private let fitting = ITextMarqueeView(text: "Short status")
    private let overflow = ITextMarqueeView(text: "This long UIKit announcement waits, then loops seamlessly when it exceeds the viewport.")
    private let attributed = ITextMarqueeView(attributedText: UIKitMarqueeExamplesViewController.richText)
    private let styled = ITextMarqueeView(text: "Styled overflowing announcement keeps moving as one line")
    private let configured = ITextMarqueeView(text: "Configured UIKit marquee moves at forty points each second", configuration: .init(speed: 40, spacing: 24, initialDelay: 0.5))
    private let rtl = ITextMarqueeView(text: "مرحبا بالعالم، هذا إعلان طويل يتحرك باتجاه دلالي صحيح")

    init() { super.init(topic: .marquee); configureExamples() }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configureExamples() {
        styled.font = .systemFont(ofSize: 20, weight: .bold)
        styled.textStyle = .init(fill: .linearGradient(.init(colors: [.systemPink, .systemOrange])), stroke: .init(paint: .solid(.systemBlue), width: 1))
        all.forEach { $0.adjustsFontForContentSizeCategory = true }
        add("uikit.marquee.fitting", "Fitting text stays static", "No overflow means no display-link motion.", "let view = ITextMarqueeView(text: \"Short status\")", fitting)
        add("uikit.marquee.overflow", "Overflowing loop", "Long content loops only after layout confirms overflow.", "let view = ITextMarqueeView(text: announcement)", overflow)
        add("uikit.marquee.attributed", "Attributed input", "NSAttributedString stays one native line.", "let view = ITextMarqueeView(attributedText: richText)", attributed)
        add("uikit.marquee.styled", "Styled input", "textStyle composes gradient fill and outward stroke.", """
        let view = ITextMarqueeView(text: "Styled overflowing announcement")
        view.textStyle = .init(
            fill: .linearGradient(.init(colors: [.systemPink, .systemOrange])),
            stroke: .init(paint: .solid(.systemBlue), width: 1)
        )
        """, styled)
        add("uikit.marquee.configuration", "Configuration", "Speed and spacing use points; delay uses seconds.", "let configuration = ITextMarqueeConfiguration(speed: 40, spacing: 24, initialDelay: 0.5)", configured)
        add("uikit.marquee.rtl", "Right to left", "The child inherits forced RTL from its container.", """
        container.semanticContentAttribute = .forceRightToLeft
        marquee.semanticContentAttribute = .unspecified
        """, rtlContainer())
        add("uikit.marquee.playback", "Playback", "Control all samples through the four public methods.", "view.start(); view.pause(); view.resume(); view.stop()", controls())
    }

    private var all: [ITextMarqueeView] { [fitting, overflow, attributed, styled, configured, rtl] }

    private func rtlContainer() -> UIView {
        let container = UIView(); container.semanticContentAttribute = .forceRightToLeft
        rtl.semanticContentAttribute = .unspecified; rtl.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(rtl)
        NSLayoutConstraint.activate([rtl.leadingAnchor.constraint(equalTo: container.leadingAnchor), rtl.trailingAnchor.constraint(equalTo: container.trailingAnchor), rtl.topAnchor.constraint(equalTo: container.topAnchor), rtl.bottomAnchor.constraint(equalTo: container.bottomAnchor)])
        container.isAccessibilityElement = true; container.accessibilityLabel = rtl.text; container.accessibilityIdentifier = "marquee.uikit.rtl"
        return container
    }

    private func controls() -> UIView {
        let buttons = [button("Start") { [weak self] in self?.all.forEach { $0.start() } }, button("Pause") { [weak self] in self?.all.forEach { $0.pause() } }, button("Resume") { [weak self] in self?.all.forEach { $0.resume() } }, button("Stop") { [weak self] in self?.all.forEach { $0.stop() } }]
        let first = row(Array(buttons[0...1])); let second = row(Array(buttons[2...3])); let stack = UIStackView(arrangedSubviews: [first, second]); stack.axis = .vertical; stack.spacing = 8; return stack
    }

    private func button(_ title: String, action: @escaping () -> Void) -> UIButton { let button = UIButton(type: .system, primaryAction: UIAction(title: title) { _ in action() }); button.configuration = .bordered(); return button }
    private func row(_ views: [UIView]) -> UIStackView { let stack = UIStackView(arrangedSubviews: views); stack.axis = .horizontal; stack.distribution = .fillEqually; stack.spacing = 8; return stack }
    private func add(_ id: String, _ title: String, _ summary: String, _ code: String, _ content: UIView) { addSection(snippet: .init(id: id, title: title, summary: summary, capabilities: [.plain, .attributed, .styled, .playback, .rtl], code: code), content: content) }
    private static let richText = NSAttributedString(string: "Bold green attributed marquee stays underlined and moves as one line.", attributes: [.font: UIFont.systemFont(ofSize: 18, weight: .bold), .foregroundColor: UIColor.systemGreen, .underlineStyle: NSUnderlineStyle.single.rawValue])
}
