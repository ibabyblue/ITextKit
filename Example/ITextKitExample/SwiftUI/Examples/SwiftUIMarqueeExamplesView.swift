import ITextKit
import SwiftUI
import UIKit

struct SwiftUIMarqueeExamplesView: View {
    @State private var playbackState: ITextPlaybackState = .playing
    @State private var playbackGeneration = 0

    var body: some View {
        SwiftUIDemoPage(
            title: DemoTopic.marquee.swiftUITitle,
            summary: DemoTopic.marquee.summary,
            capabilities: DemoTopic.marquee.capabilities
        ) {
            fittingText
            overflowingText
            attributedInput
            styledInput
            configuredInput
            rightToLeftInput
            playbackControls
        }
    }

    private var fittingText: some View {
        sample(
            id: "swiftui.marquee.fitting",
            title: "Fitting text stays static",
            summary: "Motion activates only when measured text exceeds the viewport.",
            code: """
            ITextMarquee(text: "Short status")
                .frame(maxWidth: .infinity, alignment: .leading)
            """
        ) {
            ITextMarquee(
                text: "Short status",
                playbackState: playbackState
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(playbackGeneration)
        }
    }

    private var overflowingText: some View {
        sample(
            id: "swiftui.marquee.overflow",
            title: "Overflowing loop",
            summary: "Overflowing content waits, then repeats with one semantic gap.",
            code: """
            ITextMarquee(
                text: "This long announcement waits, then loops seamlessly when it exceeds the available width."
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            """
        ) {
            ITextMarquee(
                text: Self.longText,
                playbackState: playbackState
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(playbackGeneration)
        }
    }

    private var attributedInput: some View {
        sample(
            id: "swiftui.marquee.attributed",
            title: "Attributed input",
            summary: "AttributedString keeps native inline runs while remaining one line.",
            code: """
            struct AttributedMarqueeExample: View {
                private var attributedText: AttributedString {
                    var value = AttributedString(
                        "Bold green attributed marquee stays underlined and moves as one line."
                    )
                    value.font = .system(size: 18, weight: .bold)
                    value.foregroundColor = .green
                    value.underlineStyle = .single
                    return value
                }

                var body: some View {
                    ITextMarquee(attributedText: attributedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            """
        ) {
            ITextMarquee(
                attributedText: attributedText,
                playbackState: playbackState
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(playbackGeneration)
        }
    }

    private var styledInput: some View {
        sample(
            id: "swiftui.marquee.styled",
            title: "Styled input",
            summary: "textStyle adds gradient fill and an outward outline.",
            code: """
            ITextMarquee(
                text: "Styled overflowing announcement keeps moving as one line",
                font: .systemFont(ofSize: 20, weight: .bold),
                textStyle: .init(
                    fill: .linearGradient(.init(
                        colors: [.pink, .orange]
                    )),
                    stroke: .init(
                        paint: .solid(.blue),
                        width: 1
                    )
                )
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            """
        ) {
            ITextMarquee(
                text: "Styled overflowing announcement keeps moving as one line",
                font: .systemFont(ofSize: 20, weight: .bold),
                textStyle: styledTextStyle,
                playbackState: playbackState
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(playbackGeneration)
        }
    }

    private var configuredInput: some View {
        sample(
            id: "swiftui.marquee.configuration",
            title: "Configuration",
            summary: "Speed and spacing use points; initialDelay uses seconds.",
            code: """
            ITextMarquee(
                text: "Configured marquee moves at forty points per second when this text overflows.",
                configuration: .init(
                    speed: 40,
                    spacing: 24,
                    initialDelay: 0.5
                )
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            """
        ) {
            ITextMarquee(
                text: "Configured marquee moves at forty points per second when this text overflows.",
                configuration: .init(
                    speed: 40,
                    spacing: 24,
                    initialDelay: 0.5
                ),
                playbackState: playbackState
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(playbackGeneration)
        }
    }

    private var rightToLeftInput: some View {
        sample(
            id: "swiftui.marquee.rtl",
            title: "Right to left",
            summary: "Semantic leading and motion direction follow the local layout environment.",
            code: """
            ITextMarquee(
                text: "مرحبا بالعالم، هذا إعلان طويل يتحرك باتجاه دلالي صحيح"
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\\.layoutDirection, .rightToLeft)
            """
        ) {
            ITextMarquee(
                text: "مرحبا بالعالم، هذا إعلان طويل يتحرك باتجاه دلالي صحيح",
                playbackState: playbackState
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)
            .id(playbackGeneration)
        }
    }

    private var playbackControls: some View {
        sample(
            id: "swiftui.marquee.playback",
            title: "Playback",
            summary: "SwiftUI drives playback declaratively; Start also changes identity to restart from leading.",
            code: """
            struct MarqueePlaybackExample: View {
                @State private var playbackState: ITextPlaybackState = .playing
                @State private var generation = 0

                var body: some View {
                    VStack {
                        ITextMarquee(
                            text: "A long marquee controlled by SwiftUI playback state.",
                            playbackState: playbackState
                        )
                        .id(generation)

                        HStack {
                            Button("Start") {
                                playbackState = .playing
                                generation += 1
                            }
                            Button("Pause") {
                                playbackState = .paused
                            }
                            Button("Resume") {
                                guard playbackState == .paused else { return }
                                playbackState = .playing
                            }
                            Button("Stop") {
                                playbackState = .stopped
                            }
                        }
                    }
                }
            }
            """
        ) {
            controls
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                control("Start") {
                    playbackState = .playing
                    playbackGeneration += 1
                }
                control("Pause") {
                    playbackState = .paused
                }
            }
            HStack {
                control("Resume") {
                    guard playbackState == .paused else { return }
                    playbackState = .playing
                }
                control("Stop") {
                    playbackState = .stopped
                }
            }
        }
    }

    private func control(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
    }

    private func sample<Content: View>(
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
            capabilities: [.plain, .attributed, .styled, .playback, .rtl],
            code: code
        )) {
            content()
        }
    }

    private static let longText =
        "This long announcement waits, then loops seamlessly when it exceeds the available width."

    private var styledTextStyle: ITextSwiftUIStyle {
        .init(
            fill: .linearGradient(.init(colors: [.pink, .orange])),
            stroke: .init(paint: .solid(.blue), width: 1)
        )
    }

    private var attributedText: AttributedString {
        var value = AttributedString(
            "Bold green attributed marquee stays underlined and moves as one line."
        )
        value.font = .system(size: 18, weight: .bold)
        value.foregroundColor = .green
        value.underlineStyle = .single
        return value
    }
}
