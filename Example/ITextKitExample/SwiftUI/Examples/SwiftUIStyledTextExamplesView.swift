import ITextKit
import SwiftUI
import UIKit

struct SwiftUIStyledTextExamplesView: View {
    private let font = UIFont.systemFont(ofSize: 28, weight: .bold)

    var body: some View {
        SwiftUIDemoPage(
            title: DemoTopic.styled.swiftUITitle,
            summary: DemoTopic.styled.summary,
            capabilities: DemoTopic.styled.capabilities
        ) {
            nativeReference
            gradientFill
            strokeWidths
            gradientStroke
            combinedStyle
            attributedStyle
            multilineGradient
            semanticRTL
            physicalPoints
        }
    }

    private var nativeReference: some View {
        SwiftUIDemoSection(snippet: .init(
            id: "swiftui.styled.native",
            title: "Native reference",
            summary: "Native Text remains the right choice when custom vector paint is not needed.",
            capabilities: [.plain],
            code: """
            Text("Native SwiftUI Text")
                .font(.system(size: 28, weight: .bold))
            """
        )) {
            Text("Native SwiftUI Text")
                .font(.system(size: 28, weight: .bold))
        }
    }

    private var gradientFill: some View {
        SwiftUIDemoSection(snippet: .init(
            id: "swiftui.styled.gradientFill",
            title: "Gradient fill",
            summary: "One semantic leading-to-trailing gradient spans the complete text bounds.",
            capabilities: [.styled, .rtl],
            code: """
            ITextStyledText(
                "Gradient fill",
                font: .systemFont(ofSize: 28, weight: .bold),
                style: .init(
                    fill: .linearGradient(.init(
                        colors: [.pink, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                )
            )
            """
        )) {
            ITextStyledText(
                "Gradient fill",
                font: font,
                style: gradientFillStyle
            )
        }
    }

    private var strokeWidths: some View {
        SwiftUIDemoSection(snippet: .init(
            id: "swiftui.styled.strokeWidths",
            title: "Outward stroke widths",
            summary: "The public value is the final visible thickness outside the glyph, in points.",
            capabilities: [.styled],
            code: """
            ForEach([0.5, 1, 2, 3], id: \\.self) { width in
                ITextStyledText(
                    "\\(width) pt",
                    font: .systemFont(ofSize: 24, weight: .bold),
                    style: .init(
                        fill: .solid(.white),
                        stroke: .init(paint: .solid(.blue), width: width)
                    )
                )
            }
            """
        )) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach([0.5, 1.0, 2.0, 3.0], id: \.self) { width in
                    HStack(spacing: 16) {
                        Text(widthLabel(width))
                            .font(.caption.monospacedDigit())
                            .frame(width: 44, alignment: .leading)
                        ITextStyledText(
                            "Outline",
                            font: .systemFont(ofSize: 24, weight: .bold),
                            style: .init(
                                fill: .solid(.white),
                                stroke: .init(
                                    paint: .solid(.blue),
                                    width: width
                                )
                            ),
                            adjustsFontForContentSizeCategory: false
                        )
                    }
                }
            }
            .padding(8)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var gradientStroke: some View {
        SwiftUIDemoSection(snippet: .init(
            id: "swiftui.styled.gradientStroke",
            title: "Gradient stroke",
            summary: "The outline can use its own linear gradient independently of the fill.",
            capabilities: [.styled],
            code: """
            ITextStyledText(
                "Gradient stroke",
                font: .systemFont(ofSize: 28, weight: .bold),
                style: .init(
                    fill: .solid(.white),
                    stroke: .init(
                        paint: .linearGradient(.init(
                            colors: [.yellow, .orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )),
                        width: 2
                    )
                )
            )
            """
        )) {
            ITextStyledText(
                "Gradient stroke",
                font: font,
                style: gradientStrokeStyle
            )
            .padding(8)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var combinedStyle: some View {
        SwiftUIDemoSection(snippet: .init(
            id: "swiftui.styled.combined",
            title: "Fill + stroke",
            summary: "Gradient fill, gradient outline, and shimmer compose without shrinking the fill.",
            capabilities: [.styled, .accessibility],
            code: """
            ITextStyledText(
                "Styled shimmer",
                font: .systemFont(ofSize: 28, weight: .bold),
                style: .init(
                    fill: .linearGradient(.init(colors: [.cyan, .blue, .purple])),
                    stroke: .init(
                        paint: .linearGradient(.init(
                            colors: [.yellow, .orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )),
                        width: 2
                    )
                )
            )
            .shimmerText()
            .padding(12)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 10))
            """
        )) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Styled shimmer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ITextStyledText(
                    "Fill and stroke",
                    font: font,
                    style: combined
                )
                .shimmerText()
                .padding(12)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var attributedStyle: some View {
        SwiftUIDemoSection(snippet: .init(
            id: "swiftui.styled.attributed",
            title: "Attributed",
            summary: "Use NSAttributedString and UIFont explicitly; caller-owned inline attributes are preserved.",
            capabilities: [.attributed, .styled],
            code: """
            ITextStyledText(
                attributedText: NSAttributedString(
                    string: "Rich attributed text",
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                        .foregroundColor: UIColor.systemPink,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ]
                ),
                style: .init(stroke: .init(paint: .solid(.blue), width: 1))
            )
            """
        )) {
            ITextStyledText(
                attributedText: attributedText,
                style: .init(
                    stroke: .init(paint: .solid(.blue), width: 1)
                )
            )
        }
    }

    private var multilineGradient: some View {
        SwiftUIDemoSection(snippet: .init(
            id: "swiftui.styled.multiline",
            title: "Multiline gradient",
            summary: "A single gradient spans all rendered lines instead of restarting per line.",
            capabilities: [.styled],
            code: """
            ITextStyledText(
                "One gradient continues across every wrapped line.",
                font: .systemFont(ofSize: 24, weight: .semibold),
                style: gradientStyle
            )
            .lineLimit(0)
            .frame(width: 230, alignment: .leading)
            """
        )) {
            ITextStyledText(
                "One gradient continues across every wrapped line.",
                font: .systemFont(ofSize: 24, weight: .semibold),
                style: gradientFillStyle
            )
            .lineLimit(0)
            .frame(width: 230, alignment: .leading)
        }
    }

    private var semanticRTL: some View {
        SwiftUIDemoSection(snippet: .init(
            id: "swiftui.styled.semanticRTL",
            title: "Semantic RTL",
            summary: "Leading and trailing gradient points mirror with layout direction.",
            capabilities: [.rtl, .styled],
            code: """
            ITextStyledText("مرحبا بالعالم", style: semanticGradient)
                .environment(\\.layoutDirection, .rightToLeft)
            """
        )) {
            ITextStyledText(
                "مرحبا بالعالم",
                font: font,
                style: gradientFillStyle,
                adjustsFontForContentSizeCategory: false
            )
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private var physicalPoints: some View {
        SwiftUIDemoSection(snippet: .init(
            id: "swiftui.styled.physicalPoints",
            title: "Physical unit points",
            summary: "Unit coordinates remain physical and do not mirror in right-to-left layout.",
            capabilities: [.rtl, .styled],
            code: """
            ITextStyledText(
                "Physical axis",
                style: .init(fill: .linearGradient(.init(
                    colors: [.green, .blue],
                    startPoint: .unit(x: 0, y: 0.5),
                    endPoint: .unit(x: 1, y: 0.5)
                )))
            )
            """
        )) {
            ITextStyledText(
                "Physical axis",
                font: font,
                style: .init(fill: .linearGradient(.init(
                    colors: [.green, .blue],
                    startPoint: .unit(x: 0, y: 0.5),
                    endPoint: .unit(x: 1, y: 0.5)
                ))),
                adjustsFontForContentSizeCategory: false
            )
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private var gradientFillStyle: ITextSwiftUIStyle {
        .init(fill: .linearGradient(.init(
            colors: [.pink, .orange],
            startPoint: .leading,
            endPoint: .trailing
        )))
    }

    private var gradientStrokeStyle: ITextSwiftUIStyle {
        .init(
            fill: .solid(.white),
            stroke: .init(
                paint: .linearGradient(.init(
                    colors: [.yellow, .orange, .red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )),
                width: 2
            )
        )
    }

    private var combined: ITextSwiftUIStyle {
        .init(
            fill: .linearGradient(.init(colors: [.cyan, .blue, .purple])),
            stroke: .init(
                paint: .linearGradient(.init(
                    colors: [.yellow, .orange, .red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )),
                width: 2
            )
        )
    }

    private var attributedText: NSAttributedString {
        NSAttributedString(
            string: "Rich attributed text",
            attributes: [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.systemPink,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
    }

    private func widthLabel(_ width: CGFloat) -> String {
        width == floor(width) ? "\(Int(width)) pt" : "\(width) pt"
    }
}
