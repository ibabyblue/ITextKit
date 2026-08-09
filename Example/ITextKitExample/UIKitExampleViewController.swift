import ITextKit
import UIKit

final class UIKitExampleViewController: UIViewController {
    private let rotator = ITextRotatorView(
        texts: [
            "Short UIKit message",
            "Loading in UIKit",
            "UIKit is ready"
        ]
    )

    private let marquee = ITextMarqueeView(
        text: "The UIKit marquee waits at leading, then loops this overflowing message seamlessly."
    )

    private let attributedRotator = ITextRotatorView(
        attributedTexts: UIKitExampleViewController.makeAttributedRotatorMessages()
    )

    private let attributedMarquee = ITextMarqueeView(
        attributedText: UIKitExampleViewController.makeAttributedMarqueeText()
    )

    private let typewriter = ITextTypewriterView(
        text: UIKitExampleViewController.plainTypewriterText,
        configuration: .init(charactersPerSecond: 24, initialDelay: 0.35)
    )

    private let attributedTypewriter = ITextTypewriterView(
        attributedText: UIKitExampleViewController.makeAttributedTypewriterText(),
        configuration: .init(charactersPerSecond: 24, initialDelay: 0.35)
    )

    private let settledLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureContent()
    }

    private func configureContent() {
        rotator.font = .preferredFont(forTextStyle: .title3)
        rotator.textColor = .label
        rotator.numberOfLines = 1
        rotator.adjustsFontForContentSizeCategory = true
        rotator.onTextChange = { [weak self] index, _ in
            self?.settledLabel.text = "Settled index: \(index)"
        }

        marquee.font = .preferredFont(forTextStyle: .body)
        marquee.textColor = .label
        marquee.adjustsFontForContentSizeCategory = true

        attributedRotator.numberOfLines = 1
        attributedRotator.adjustsFontForContentSizeCategory = true

        attributedMarquee.adjustsFontForContentSizeCategory = true

        typewriter.font = .preferredFont(forTextStyle: .body)
        typewriter.textColor = .label
        typewriter.numberOfLines = 0
        typewriter.adjustsFontForContentSizeCategory = true

        attributedTypewriter.numberOfLines = 0
        attributedTypewriter.adjustsFontForContentSizeCategory = true

        settledLabel.font = .preferredFont(forTextStyle: .caption1)
        settledLabel.textColor = .secondaryLabel
        settledLabel.text = "Initial item"

        let stack = UIStackView(arrangedSubviews: [
            heading("Plain rotator"),
            card(containing: rotator, color: .systemBlue),
            settledLabel,
            heading("Attributed rotator"),
            card(containing: attributedRotator, color: .systemPurple),
            makeControls(),
            heading("Plain overflow-only marquee"),
            card(containing: marquee, color: .systemOrange),
            heading("Attributed overflow-only marquee"),
            card(containing: attributedMarquee, color: .systemGreen),
            makeTypewriterReplayButton(),
            heading("Plain typewriter"),
            typewriterCard(containing: typewriter, color: .systemCyan),
            heading("Attributed typewriter"),
            typewriterCard(containing: attributedTypewriter, color: .systemIndigo)
        ])
        stack.axis = .vertical
        stack.spacing = 20
        stack.setCustomSpacing(8, after: settledLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }

    private func makeControls() -> UIView {
        let start = playbackButton(title: "Start") { [weak self] in
            self?.rotator.start()
            self?.marquee.start()
            self?.attributedRotator.start()
            self?.attributedMarquee.start()
        }
        let pause = playbackButton(title: "Pause") { [weak self] in
            self?.rotator.pause()
            self?.marquee.pause()
            self?.attributedRotator.pause()
            self?.attributedMarquee.pause()
        }
        let resume = playbackButton(title: "Resume") { [weak self] in
            self?.rotator.resume()
            self?.marquee.resume()
            self?.attributedRotator.resume()
            self?.attributedMarquee.resume()
        }
        let stop = playbackButton(title: "Stop") { [weak self] in
            self?.rotator.stop()
            self?.marquee.stop()
            self?.attributedRotator.stop()
            self?.attributedMarquee.stop()
        }

        let firstRow = controlRow([start, pause])
        let secondRow = controlRow([resume, stop])
        let stack = UIStackView(arrangedSubviews: [firstRow, secondRow])
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }

    private func makeTypewriterReplayButton() -> UIView {
        playbackButton(title: "Replay Typewriter") { [weak self] in
            guard let self else { return }
            typewriter.text = ""
            attributedTypewriter.attributedText = NSAttributedString(string: "")
            typewriter.text = Self.plainTypewriterText
            attributedTypewriter.attributedText = Self.makeAttributedTypewriterText()
        }
    }

    private func playbackButton(title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system, primaryAction: UIAction(title: title) { _ in action() })
        button.configuration = .bordered()
        return button
    }

    private func controlRow(_ buttons: [UIButton]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: buttons)
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 8
        return row
    }

    private func card(containing content: UIView, color: UIColor) -> UIView {
        let card = UIView()
        card.backgroundColor = color.withAlphaComponent(0.12)
        card.layer.cornerRadius = 16
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return card
    }

    private func typewriterCard(containing content: UIView, color: UIColor) -> UIView {
        let card = UIView()
        card.backgroundColor = color.withAlphaComponent(0.12)
        card.layer.cornerRadius = 16

        let container = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        card.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        container.addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            card.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return container
    }

    private func heading(_ text: String) -> UILabel {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.text = text
        return label
    }

    private static func makeAttributedRotatorMessages() -> [NSAttributedString] {
        let first = NSAttributedString(
            string: "Bold purple UIKit text",
            attributes: [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.systemPurple
            ]
        )
        let second = NSAttributedString(
            string: "Underlined UIKit status",
            attributes: [
                .font: UIFont.systemFont(ofSize: 28, weight: .semibold),
                .foregroundColor: UIColor.systemIndigo,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        return [first, second]
    }

    private static let plainTypewriterText =
        "A plain UIKit typewriter grows wider, then wraps and grows taller."

    private static func makeAttributedMarqueeText() -> NSAttributedString {
        NSAttributedString(
            string: "This bold green UIKit attributed marquee is underlined and moves as one native line.",
            attributes: [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor.systemGreen,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
    }

    private static func makeAttributedTypewriterText() -> NSAttributedString {
        NSAttributedString(
            string: "Rich 👨‍👩‍👧‍👦 UIKit typewriter text keeps its color, weight, and underline while it grows.",
            attributes: [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor.systemIndigo,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
    }
}
