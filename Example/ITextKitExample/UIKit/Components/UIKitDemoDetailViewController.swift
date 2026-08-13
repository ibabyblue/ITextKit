import UIKit

class UIKitDemoDetailViewController: UIViewController {
    let contentStack = UIStackView()

    init(topic: DemoTopic) {
        super.init(nibName: nil, bundle: nil)
        title = topic.uiKitTitle
        configurePage(topic: topic)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addSection(snippet: DemoSnippet, content: UIView) {
        contentStack.addArrangedSubview(
            UIKitDemoSectionView(snippet: snippet, content: content)
        )
    }

    private func configurePage(topic: DemoTopic) {
        view.backgroundColor = .systemBackground

        let summary = UILabel()
        summary.text = topic.summary
        summary.font = .preferredFont(forTextStyle: .body)
        summary.textColor = .secondaryLabel
        summary.numberOfLines = 0
        summary.adjustsFontForContentSizeCategory = true

        let tags = UILabel()
        tags.text = topic.capabilities.map(\.rawValue).joined(separator: " · ")
        tags.font = .preferredFont(forTextStyle: .caption1)
        tags.textColor = .tintColor
        tags.numberOfLines = 0

        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(summary)
        contentStack.addArrangedSubview(tags)

        let introduction = UILabel()
        introduction.text = topic.summary
        introduction.numberOfLines = 0
        introduction.font = .preferredFont(forTextStyle: .body)
        addSection(snippet: topic.introductionSnippet, content: introduction)

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor,
                constant: 20
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.trailingAnchor,
                constant: -20
            ),
            contentStack.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor,
                constant: 20
            ),
            contentStack.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor,
                constant: -24
            ),
            contentStack.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor,
                constant: -40
            )
        ])
    }
}
