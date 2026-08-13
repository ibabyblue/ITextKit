import UIKit

final class UIKitDemoSectionView: UIStackView {
    init(snippet: DemoSnippet, content: UIView) {
        super.init(frame: .zero)
        axis = .vertical
        spacing = 12

        let title = UILabel()
        title.text = snippet.title
        title.font = .preferredFont(forTextStyle: .headline)
        title.adjustsFontForContentSizeCategory = true

        let summary = UILabel()
        summary.text = snippet.summary
        summary.font = .preferredFont(forTextStyle: .subheadline)
        summary.textColor = .secondaryLabel
        summary.numberOfLines = 0
        summary.adjustsFontForContentSizeCategory = true

        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        addArrangedSubview(title)
        addArrangedSubview(summary)
        addArrangedSubview(card)
        addArrangedSubview(UIKitDemoCodeView(snippet: snippet))
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
