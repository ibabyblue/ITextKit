import UIKit

final class UIKitDemoCodeView: UIView {
    private let snippet: DemoSnippet
    private let copyButton = UIButton(type: .system)

    init(snippet: DemoSnippet) {
        self.snippet = snippet
        super.init(frame: .zero)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        let title = UILabel()
        title.text = "Code"
        title.font = .preferredFont(forTextStyle: .caption1)
        title.textColor = .secondaryLabel

        copyButton.setTitle("Copy", for: .normal)
        copyButton.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
        copyButton.accessibilityLabel = "Copy \(snippet.title) code"
        copyButton.accessibilityIdentifier = "copy.\(snippet.id)"
        copyButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            UIPasteboard.general.string = snippet.code
            copyButton.setTitle("Copied", for: .normal)
            copyButton.accessibilityLabel = "Copied"
        }, for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [title, copyButton])
        header.axis = .horizontal
        header.alignment = .center

        let codeView = UITextView()
        codeView.text = snippet.code
        codeView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        codeView.backgroundColor = .secondarySystemBackground
        codeView.isEditable = false
        codeView.isSelectable = true
        codeView.isScrollEnabled = true
        codeView.showsHorizontalScrollIndicator = true
        codeView.textContainer.lineBreakMode = .byClipping
        codeView.textContainer.widthTracksTextView = false
        codeView.textContainer.size = CGSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        codeView.layer.cornerRadius = 10
        codeView.accessibilityLabel = snippet.code
        codeView.accessibilityIdentifier = "code.\(snippet.id)"

        let stack = UIStackView(arrangedSubviews: [header, codeView])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            codeView.heightAnchor.constraint(equalToConstant: 120)
        ])
    }
}
