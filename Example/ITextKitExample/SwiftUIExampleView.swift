import ITextKit
import SwiftUI

struct SwiftUIExampleView: View {
    @State private var playbackState = ITextPlaybackState.playing
    @State private var playbackGeneration = 0
    @State private var settledDescription = "Initial item"

    private let messages = [
        "A short message",
        "Loading your space",
        "Ready to continue"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                sectionTitle("Plain rotator")

                ITextRotator(
                    texts: messages,
                    playbackState: playbackState
                )
                .onTextRotatorChange { index, _ in
                    settledDescription = "Settled index: \(index)"
                }
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                .id(playbackGeneration)

                Text(settledDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                sectionTitle("Attributed rotator")

                ITextRotator(
                    attributedTexts: attributedMessages,
                    playbackState: playbackState
                )
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                .id(playbackGeneration)

                playbackControls

                sectionTitle("Plain overflow-only marquee")

                ITextMarquee(
                    text: "This long announcement waits, then loops seamlessly when it exceeds the available width.",
                    playbackState: playbackState
                )
                .font(.body.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                .id(playbackGeneration)

                sectionTitle("Attributed overflow-only marquee")

                ITextMarquee(
                    attributedText: attributedMarquee,
                    playbackState: playbackState
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                .id(playbackGeneration)
            }
            .padding()
        }
    }

    private var attributedMessages: [AttributedString] {
        var first = AttributedString("Bold purple text")
        first.font = .system(size: 22, weight: .bold)
        first.foregroundColor = .purple

        var second = AttributedString("Underlined status")
        second.font = .system(size: 28, weight: .semibold)
        second.foregroundColor = .indigo
        second.underlineStyle = .single
        return [first, second]
    }

    private var attributedMarquee: AttributedString {
        var value = AttributedString("This bold green attributed marquee includes an underlined visual phrase and keeps moving as one line.")
        value.font = .system(size: 18, weight: .bold)
        value.foregroundColor = .green
        value.underlineStyle = .single
        return value
    }

    private var playbackControls: some View {
        VStack(spacing: 8) {
            HStack {
                playbackButton("Start", action: start)
                playbackButton("Pause") {
                    playbackState = .paused
                }
            }

            HStack {
                playbackButton("Resume", action: resume)
                playbackButton("Stop") {
                    playbackState = .stopped
                }
            }
        }
        .buttonStyle(.bordered)
    }

    private func playbackButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .frame(maxWidth: .infinity)
    }

    private func start() {
        playbackState = .playing
        playbackGeneration += 1
        settledDescription = "Initial item"
    }

    private func resume() {
        guard playbackState == .paused else { return }
        playbackState = .playing
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }
}
