import ITextKit
import UIKit

final class UIKitExampleViewController: UIViewController {
    private let rotator = ITextRotatorView(
        texts: [
            "A short UIKit message",
            "This longer UIKit message demonstrates intrinsic height following the current multiline text.",
            "Compact again"
        ]
    )

    private let marquee = ITextMarqueeView(
        text: "The UIKit marquee waits at leading, then loops this overflowing message seamlessly."
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
        rotator.numberOfLines = 0
        rotator.adjustsFontForContentSizeCategory = true
        rotator.onTextChange = { [weak self] index, _ in
            self?.settledLabel.text = "Settled index: \(index)"
        }

        marquee.font = .preferredFont(forTextStyle: .body)
        marquee.textColor = .label
        marquee.adjustsFontForContentSizeCategory = true

        settledLabel.font = .preferredFont(forTextStyle: .caption1)
        settledLabel.textColor = .secondaryLabel
        settledLabel.text = "Initial item"

        let stack = UIStackView(arrangedSubviews: [
            heading("Variable-height rotator"),
            card(containing: rotator, color: .systemBlue),
            settledLabel,
            makeControls(),
            heading("Overflow-only marquee"),
            card(containing: marquee, color: .systemOrange)
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
        }
        let pause = playbackButton(title: "Pause") { [weak self] in
            self?.rotator.pause()
            self?.marquee.pause()
        }
        let resume = playbackButton(title: "Resume") { [weak self] in
            self?.rotator.resume()
            self?.marquee.resume()
        }
        let stop = playbackButton(title: "Stop") { [weak self] in
            self?.rotator.stop()
            self?.marquee.stop()
        }

        let firstRow = controlRow([start, pause])
        let secondRow = controlRow([resume, stop])
        let stack = UIStackView(arrangedSubviews: [firstRow, secondRow])
        stack.axis = .vertical
        stack.spacing = 8
        return stack
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

    private func heading(_ text: String) -> UILabel {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.text = text
        return label
    }
}
