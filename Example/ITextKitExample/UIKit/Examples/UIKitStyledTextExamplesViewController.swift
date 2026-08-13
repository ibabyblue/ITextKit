import ITextKit
import UIKit

final class UIKitStyledTextExamplesViewController: UIKitDemoDetailViewController {
    init() {
        super.init(topic: .styled)
        configureExamples()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureExamples() {
        addSection(
            snippet: snippet(
                id: "uikit.styled.native",
                title: "Native UILabel reference",
                summary: "Keep using UILabel when custom vector paint is unnecessary.",
                code: """
                let label = UILabel()
                label.text = "Native UILabel"
                label.font = .systemFont(ofSize: 28, weight: .bold)
                """
            ),
            content: nativeLabel()
        )

        addSection(
            snippet: snippet(
                id: "uikit.styled.gradientFill",
                title: "Gradient fill",
                summary: "One semantic gradient spans the complete label bounds.",
                code: """
                let label = ITextStyledLabel()
                label.text = "Gradient fill"
                label.font = .systemFont(ofSize: 28, weight: .bold)
                label.textStyle = .init(
                    fill: .linearGradient(.init(
                        colors: [.systemPink, .systemOrange],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                )
                """
            ),
            content: styledLabel(text: "Gradient fill", style: gradientFill)
        )

        addSection(
            snippet: snippet(
                id: "uikit.styled.strokeWidths",
                title: "Outward stroke widths",
                summary: "The visible outward thickness is expressed directly in points.",
                code: """
                [0.5, 1, 2, 3].forEach { width in
                    let label = ITextStyledLabel()
                    label.text = "\\(width) pt"
                    label.textStyle = .init(
                        fill: .solid(.white),
                        stroke: .init(paint: .solid(.systemBlue), width: width)
                    )
                }
                """
            ),
            content: strokeWidthStack()
        )

        addSection(
            snippet: snippet(
                id: "uikit.styled.gradientStroke",
                title: "Gradient stroke",
                summary: "The outline owns a linear gradient independent of the fill.",
                code: """
                let label = ITextStyledLabel()
                label.text = "Gradient stroke"
                label.font = .systemFont(ofSize: 28, weight: .bold)
                label.textStyle = .init(
                    fill: .solid(.white),
                    stroke: .init(
                        paint: .linearGradient(.init(
                            colors: [.systemYellow, .systemOrange, .systemRed],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )),
                        width: 2
                    )
                )
                """
            ),
            content: darkCardLabel(
                styledLabel(text: "Gradient stroke", style: gradientStroke)
            )
        )

        addSection(
            snippet: snippet(
                id: "uikit.styled.combined",
                title: "Fill + stroke",
                summary: "Gradient fill and gradient outline share one vector layout.",
                code: """
                let label = ITextStyledLabel()
                label.text = "Fill and stroke"
                label.font = .systemFont(ofSize: 28, weight: .bold)
                label.textStyle = .init(
                    fill: .linearGradient(.init(
                        colors: [.systemCyan, .systemBlue, .systemPurple]
                    )),
                    stroke: .init(
                        paint: .linearGradient(.init(
                            colors: [.systemYellow, .systemOrange, .systemRed],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )),
                        width: 2
                    )
                )
                """
            ),
            content: darkCardLabel(
                styledLabel(text: "Fill and stroke", style: combined)
            )
        )

        addSection(
            snippet: snippet(
                id: "uikit.styled.attributed",
                title: "Attributed",
                summary: "NSAttributedString runs remain caller-owned and are copied on assignment.",
                code: """
                let label = ITextStyledLabel()
                label.attributedText = NSAttributedString(
                    string: "Rich attributed label",
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                        .foregroundColor: UIColor.systemPink,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ]
                )
                label.textStyle = .init(
                    stroke: .init(paint: .solid(.systemBlue), width: 1)
                )
                """
            ),
            content: attributedLabel()
        )

        addSection(
            snippet: snippet(
                id: "uikit.styled.multiline",
                title: "Multiline gradient",
                summary: "The gradient continues across every line instead of restarting.",
                code: """
                let label = ITextStyledLabel()
                label.text = "One gradient continues across every wrapped line."
                label.font = .systemFont(ofSize: 24, weight: .semibold)
                label.numberOfLines = 0
                label.textStyle = gradientStyle
                label.widthAnchor.constraint(equalToConstant: 230).isActive = true
                """
            ),
            content: multilineLabel()
        )

        addSection(
            snippet: snippet(
                id: "uikit.styled.intrinsic",
                title: "Intrinsic size",
                summary: "The label automatically reserves outward stroke space without fixed dimensions.",
                code: """
                let label = ITextStyledLabel()
                label.text = "Intrinsic size"
                label.font = .systemFont(ofSize: 26, weight: .bold)
                label.textStyle = .init(
                    stroke: .init(paint: .solid(.systemBlue), width: 2)
                )
                // No width or height constraint is required.
                """
            ),
            content: styledLabel(
                text: "Intrinsic size",
                style: .init(
                    stroke: .init(paint: .solid(.systemBlue), width: 2)
                )
            )
        )

        addSection(
            snippet: snippet(
                id: "uikit.styled.autoLayout",
                title: "Auto Layout",
                summary: "A width constraint is enough for multiline content to derive its height.",
                code: """
                let label = ITextStyledLabel()
                label.translatesAutoresizingMaskIntoConstraints = false
                label.text = "Auto Layout supplies width; the label supplies height."
                label.numberOfLines = 0
                label.textStyle = gradientStyle
                NSLayoutConstraint.activate([
                    label.widthAnchor.constraint(equalToConstant: 230)
                ])
                """
            ),
            content: autoLayoutLabel()
        )

        addSection(
            snippet: snippet(
                id: "uikit.styled.semanticRTL",
                title: "Semantic RTL",
                summary: "Leading and trailing gradient points follow inherited semantic direction.",
                code: """
                let container = UIView()
                container.semanticContentAttribute = .forceRightToLeft
                let label = ITextStyledLabel()
                label.semanticContentAttribute = .unspecified
                label.text = "مرحبا بالعالم"
                label.textStyle = semanticGradientStyle
                """
            ),
            content: rtlLabel()
        )
    }

    private var gradientFill: ITextUIKitStyle {
        .init(fill: .linearGradient(.init(
            colors: [.systemPink, .systemOrange],
            startPoint: .leading,
            endPoint: .trailing
        )))
    }

    private var gradientStroke: ITextUIKitStyle {
        .init(
            fill: .solid(.white),
            stroke: .init(
                paint: .linearGradient(.init(
                    colors: [.systemYellow, .systemOrange, .systemRed],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )),
                width: 2
            )
        )
    }

    private var combined: ITextUIKitStyle {
        .init(
            fill: .linearGradient(.init(
                colors: [.systemCyan, .systemBlue, .systemPurple]
            )),
            stroke: .init(
                paint: .linearGradient(.init(
                    colors: [.systemYellow, .systemOrange, .systemRed],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )),
                width: 2
            )
        )
    }

    private func nativeLabel() -> UILabel {
        let label = UILabel()
        label.text = "Native UILabel"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        return label
    }

    private func styledLabel(
        text: String,
        style: ITextUIKitStyle
    ) -> ITextStyledLabel {
        let label = ITextStyledLabel()
        label.text = text
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textStyle = style
        return label
    }

    private func strokeWidthStack() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        [0.5, 1.0, 2.0, 3.0].forEach { width in
            let caption = UILabel()
            caption.text = width == floor(width)
                ? "\(Int(width)) pt"
                : "\(width) pt"
            caption.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
            caption.textColor = .white
            caption.widthAnchor.constraint(equalToConstant: 44).isActive = true

            let value = styledLabel(
                text: "Outline",
                style: .init(
                    fill: .solid(.white),
                    stroke: .init(paint: .solid(.systemBlue), width: width)
                )
            )
            let row = UIStackView(arrangedSubviews: [caption, value])
            row.axis = .horizontal
            row.spacing = 16
            stack.addArrangedSubview(row)
        }
        return darkCardLabel(stack)
    }

    private func darkCardLabel(_ content: UIView) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        container.layer.cornerRadius = 10
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
        return container
    }

    private func attributedLabel() -> ITextStyledLabel {
        let label = ITextStyledLabel()
        label.attributedText = NSAttributedString(
            string: "Rich attributed label",
            attributes: [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.systemPink,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        label.textStyle = .init(
            stroke: .init(paint: .solid(.systemBlue), width: 1)
        )
        return label
    }

    private func multilineLabel() -> ITextStyledLabel {
        let label = styledLabel(
            text: "One gradient continues across every wrapped line.",
            style: gradientFill
        )
        label.font = .systemFont(ofSize: 24, weight: .semibold)
        label.numberOfLines = 0
        label.widthAnchor.constraint(equalToConstant: 230).isActive = true
        return label
    }

    private func autoLayoutLabel() -> ITextStyledLabel {
        let label = styledLabel(
            text: "Auto Layout supplies width; the label supplies height.",
            style: gradientFill
        )
        label.numberOfLines = 0
        label.widthAnchor.constraint(equalToConstant: 230).isActive = true
        return label
    }

    private func rtlLabel() -> UIView {
        let container = UIView()
        container.semanticContentAttribute = .forceRightToLeft
        let label = styledLabel(text: "مرحبا بالعالم", style: gradientFill)
        label.semanticContentAttribute = .unspecified
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func snippet(
        id: String,
        title: String,
        summary: String,
        code: String
    ) -> DemoSnippet {
        .init(
            id: id,
            title: title,
            summary: summary,
            capabilities: [.styled],
            code: code
        )
    }
}
