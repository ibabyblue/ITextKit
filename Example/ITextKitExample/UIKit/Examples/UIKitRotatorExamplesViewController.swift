import ITextKit
import UIKit

final class UIKitRotatorExamplesViewController: UIKitDemoDetailViewController {
    private let configuration = ITextRotatorConfiguration(interval: 4, transitionDuration: 0.25)
    private let settledLabel = UILabel()
    private lazy var plain = ITextRotatorView(texts: ["First message", "Second message", "Third message"], configuration: configuration)
    private lazy var attributed = ITextRotatorView(attributedTexts: Self.richValues, configuration: configuration)
    private lazy var styled = ITextRotatorView(texts: ["Gradient one", "Gradient two"], configuration: configuration)
    private lazy var variable = ITextRotatorView(texts: ["Short", "A longer value wraps naturally without a fixed component height."], configuration: configuration)

    init() {
        super.init(topic: .rotator)
        configureExamples()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configureExamples() {
        configureViews()
        add("uikit.rotator.plain", "Plain input", "Strings use UILabel-compatible styling.", """
        let view = ITextRotatorView(texts: ["First", "Second", "Third"])
        view.font = .preferredFont(forTextStyle: .headline)
        """, plain)
        add("uikit.rotator.attributed", "Attributed input", "NSAttributedString runs remain intact.", """
        let view = ITextRotatorView(attributedTexts: richValues)
        """, attributed)
        add("uikit.rotator.styled", "Styled input", "textStyle applies vector fill and outline to each value.", """
        let view = ITextRotatorView(texts: ["Gradient one", "Gradient two"])
        view.textStyle = .init(
            fill: .linearGradient(.init(colors: [.systemPink, .systemOrange])),
            stroke: .init(paint: .solid(.systemBlue), width: 1)
        )
        """, styled)
        add("uikit.rotator.variableHeight", "Variable height", "Leading/trailing constraints provide width; intrinsic height follows content.", """
        view.numberOfLines = 0
        // Constrain leading and trailing only; do not add a height constraint.
        """, variable)
        add("uikit.rotator.playback", "Playback and callback", "Public methods control every sample and onTextChange reports settled values.", """
        view.onTextChange = { index, text in
            settledLabel.text = "Settled index: \\(index)"
        }
        view.start(); view.pause(); view.resume(); view.stop()
        """, playbackControls())
    }

    private func configureViews() {
        [plain, styled].forEach {
            $0.font = .preferredFont(forTextStyle: .headline)
            $0.numberOfLines = 1
            $0.adjustsFontForContentSizeCategory = true
        }
        attributed.numberOfLines = 1
        styled.textStyle = .init(
            fill: .linearGradient(.init(colors: [.systemPink, .systemOrange])),
            stroke: .init(paint: .solid(.systemBlue), width: 1)
        )
        variable.numberOfLines = 0
        variable.font = .preferredFont(forTextStyle: .body)
        plain.onTextChange = { [weak self] index, _ in
            self?.settledLabel.text = "Settled index: \(index)"
        }
        settledLabel.text = "Settled index: 0"
        settledLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
    }

    private func playbackControls() -> UIView {
        let buttons = [
            makeButton("Start") { [weak self] in self?.all.forEach { $0.start() } },
            makeButton("Pause") { [weak self] in self?.all.forEach { $0.pause() } },
            makeButton("Resume") { [weak self] in self?.all.forEach { $0.resume() } },
            makeButton("Stop") { [weak self] in self?.all.forEach { $0.stop() } }
        ]
        let first = row(Array(buttons[0...1]))
        let second = row(Array(buttons[2...3]))
        let stack = UIStackView(arrangedSubviews: [settledLabel, first, second])
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }

    private var all: [ITextRotatorView] { [plain, attributed, styled, variable] }

    private func makeButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system, primaryAction: UIAction(title: title) { _ in action() })
        button.configuration = .bordered()
        return button
    }

    private func row(_ views: [UIView]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        return stack
    }

    private func add(_ id: String, _ title: String, _ summary: String, _ code: String, _ content: UIView) {
        addSection(snippet: .init(id: id, title: title, summary: summary, capabilities: [.plain, .attributed, .styled, .playback], code: code), content: content)
    }

    private static var richValues: [NSAttributedString] {
        [
            NSAttributedString(string: "Bold purple value", attributes: [.font: UIFont.systemFont(ofSize: 22, weight: .bold), .foregroundColor: UIColor.systemPurple]),
            NSAttributedString(string: "Underlined value", attributes: [.font: UIFont.systemFont(ofSize: 24, weight: .semibold), .foregroundColor: UIColor.systemIndigo, .underlineStyle: NSUnderlineStyle.single.rawValue])
        ]
    }
}
