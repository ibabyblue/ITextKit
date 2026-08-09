import ITextKit
import SwiftUI

struct SwiftUIExampleView: View {
    @State private var playbackState = ITextPlaybackState.playing
    @State private var playbackGeneration = 0
    @State private var settledDescription = "Initial item"

    private let messages = [
        "A short message",
        "The rotator grows while this longer message wraps naturally across multiple lines.",
        "Small again"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                sectionTitle("Variable-height rotator")

                ITextRotator(
                    texts: messages,
                    playbackState: playbackState
                )
                .onTextRotatorChange { index, _ in
                    settledDescription = "Settled index: \(index)"
                }
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                .id(playbackGeneration)

                Text(settledDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                playbackControls

                sectionTitle("Overflow-only marquee")

                ITextMarquee(
                    text: "This long announcement waits, then loops seamlessly when it exceeds the available width.",
                    playbackState: playbackState
                )
                .font(.body.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                .id(playbackGeneration)
            }
            .padding()
        }
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
