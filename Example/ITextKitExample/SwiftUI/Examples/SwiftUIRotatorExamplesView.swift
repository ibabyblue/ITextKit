import ITextKit
import SwiftUI
import UIKit

struct SwiftUIRotatorExamplesView: View {
    @State private var playback: ITextPlaybackState = .playing
    @State private var generation = 0
    @State private var settledIndex = 0

    private let configuration = ITextRotatorConfiguration(
        interval: 4,
        transitionDuration: 0.25
    )

    var body: some View {
        SwiftUIDemoPage(
            title: DemoTopic.rotator.swiftUITitle,
            summary: DemoTopic.rotator.summary,
            capabilities: DemoTopic.rotator.capabilities
        ) {
            plain
            attributed
            styled
            variableHeight
            playbackSection
        }
    }

    private var plain: some View {
        section(
            id: "swiftui.rotator.plain",
            title: "Plain input",
            summary: "Rotate localized String values with native Text modifiers.",
            code: """
            ITextRotator(texts: ["First", "Second", "Third"])
                .font(.headline)
                .lineLimit(1)
            """
        ) {
            ITextRotator(
                texts: ["First message", "Second message", "Third message"],
                configuration: configuration,
                playbackState: playback
            )
            .font(.headline)
            .id(generation)
        }
    }

    private var attributed: some View {
        section(
            id: "swiftui.rotator.attributed",
            title: "Attributed input",
            summary: "AttributedString runs keep their own color, font, and decoration.",
            code: """
            ITextRotator(attributedTexts: richValues)
            """
        ) {
            ITextRotator(
                attributedTexts: richValues,
                configuration: configuration,
                playbackState: playback
            )
            .id(generation)
        }
    }

    private var styled: some View {
        section(
            id: "swiftui.rotator.styled",
            title: "Styled input",
            summary: "Use textStyle when every rotating value needs vector fill and outline.",
            code: """
            ITextRotator(
                texts: ["Gradient one", "Gradient two"],
                font: .systemFont(ofSize: 24, weight: .bold),
                textStyle: .init(
                    fill: .linearGradient(.init(colors: [.pink, .orange])),
                    stroke: .init(paint: .solid(.blue), width: 1)
                )
            )
            """
        ) {
            ITextRotator(
                texts: ["Gradient one", "Gradient two"],
                font: .systemFont(ofSize: 24, weight: .bold),
                textStyle: styledTextStyle,
                configuration: configuration,
                playbackState: playback
            )
            .id(generation)
        }
    }

    private var variableHeight: some View {
        section(
            id: "swiftui.rotator.variableHeight",
            title: "Variable height",
            summary: "The ideal height follows the current value and reserves both values during transition.",
            code: """
            ITextRotator(texts: [
                "Short",
                "A longer value wraps naturally without a fixed component height."
            ])
            .frame(width: 240, alignment: .leading)
            """
        ) {
            ITextRotator(
                texts: [
                    "Short",
                    "A longer value wraps naturally without a fixed component height."
                ],
                configuration: configuration,
                playbackState: playback
            )
            .frame(width: 240, alignment: .leading)
            .id(generation)
        }
    }

    private var playbackSection: some View {
        section(
            id: "swiftui.rotator.playback",
            title: "Playback and callback",
            summary: "Start restarts; Pause freezes; Resume continues; Stop keeps the settled value.",
            code: """
            ITextRotator(texts: values, playbackState: playback)
                .onTextRotatorChange { index, text in
                    settledIndex = index
                }
            """
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Settled index: \(settledIndex)")
                    .font(.caption.monospacedDigit())
                controls
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                button("Start") {
                    playback = .playing
                    generation += 1
                    settledIndex = 0
                }
                button("Pause") { playback = .paused }
            }
            HStack {
                button("Resume") {
                    if playback == .paused { playback = .playing }
                }
                button("Stop") { playback = .stopped }
            }
        }
    }

    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
    }

    private func section<Content: View>(
        id: String,
        title: String,
        summary: String,
        code: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        SwiftUIDemoSection(snippet: .init(
            id: id,
            title: title,
            summary: summary,
            capabilities: [.plain, .attributed, .styled, .playback],
            code: code
        )) {
            content()
        }
    }

    private var styledTextStyle: ITextSwiftUIStyle {
        .init(
            fill: .linearGradient(.init(colors: [.pink, .orange])),
            stroke: .init(paint: .solid(.blue), width: 1)
        )
    }

    private var richValues: [AttributedString] {
        var first = AttributedString("Bold purple value")
        first.font = .system(size: 22, weight: .bold)
        first.foregroundColor = .purple
        var second = AttributedString("Underlined value")
        second.font = .system(size: 24, weight: .semibold)
        second.foregroundColor = .indigo
        second.underlineStyle = .single
        return [first, second]
    }
}
