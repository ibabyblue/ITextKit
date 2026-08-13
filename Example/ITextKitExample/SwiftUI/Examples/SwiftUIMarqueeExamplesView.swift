import ITextKit
import SwiftUI
import UIKit

struct SwiftUIMarqueeExamplesView: View {
    @State private var playback: ITextPlaybackState = .playing
    @State private var generation = 0

    var body: some View {
        SwiftUIDemoPage(title: DemoTopic.marquee.swiftUITitle, summary: DemoTopic.marquee.summary, capabilities: DemoTopic.marquee.capabilities) {
            sample("swiftui.marquee.fitting", "Fitting text stays static", "Motion activates only when measured text exceeds the viewport.", "ITextMarquee(text: \"Short status\")") {
                ITextMarquee(text: "Short status", playbackState: playback).id(generation)
            }
            sample("swiftui.marquee.overflow", "Overflowing loop", "Overflowing content waits, then repeats with one semantic gap.", "ITextMarquee(text: longText)") {
                ITextMarquee(text: longText, playbackState: playback).id(generation)
            }
            sample("swiftui.marquee.attributed", "Attributed input", "AttributedString keeps native inline runs while remaining one line.", "ITextMarquee(attributedText: attributedText)") {
                ITextMarquee(attributedText: attributedText, playbackState: playback).id(generation)
            }
            sample("swiftui.marquee.styled", "Styled input", "textStyle adds gradient fill and an outward outline.", """
            ITextMarquee(
                text: "Styled overflowing announcement",
                font: .systemFont(ofSize: 20, weight: .bold),
                textStyle: .init(
                    fill: .linearGradient(.init(colors: [.pink, .orange])),
                    stroke: .init(paint: .solid(.blue), width: 1)
                )
            )
            """) {
                ITextMarquee(text: "Styled overflowing announcement keeps moving as one line", font: .systemFont(ofSize: 20, weight: .bold), textStyle: style, playbackState: playback).id(generation)
            }
            sample("swiftui.marquee.configuration", "Configuration", "Speed is points per second; spacing is points; initialDelay is seconds.", """
            ITextMarquee(
                text: announcement,
                configuration: .init(speed: 40, spacing: 24, initialDelay: 0.5)
            )
            """) {
                ITextMarquee(text: longText, configuration: .init(speed: 40, spacing: 24, initialDelay: 0.5), playbackState: playback).id(generation)
            }
            sample("swiftui.marquee.rtl", "Right to left", "Semantic leading and motion direction follow the local layout environment.", """
            ITextMarquee(text: "مرحبا بالعالم، هذا إعلان طويل يتحرك باتجاه دلالي صحيح")
                .environment(\\.layoutDirection, .rightToLeft)
            """) {
                ITextMarquee(text: "مرحبا بالعالم، هذا إعلان طويل يتحرك باتجاه دلالي صحيح", playbackState: playback)
                    .environment(\.layoutDirection, .rightToLeft)
                    .id(generation)
            }
            sample("swiftui.marquee.playback", "Playback", "Start restarts from leading; Pause freezes; Resume continues; Stop returns to leading.", "marquee.start(); marquee.pause(); marquee.resume(); marquee.stop()") {
                controls
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack { control("Start") { playback = .playing; generation += 1 }; control("Pause") { playback = .paused } }
            HStack { control("Resume") { if playback == .paused { playback = .playing } }; control("Stop") { playback = .stopped } }
        }
    }

    private func control(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action).buttonStyle(.bordered).frame(maxWidth: .infinity)
    }

    private func sample<Content: View>(_ id: String, _ title: String, _ summary: String, _ code: String, @ViewBuilder content: () -> Content) -> some View {
        SwiftUIDemoSection(snippet: .init(id: id, title: title, summary: summary, capabilities: [.plain, .attributed, .styled, .playback, .rtl], code: code)) { content() }
    }

    private let longText = "This long announcement waits, then loops seamlessly when it exceeds the available width."
    private var style: ITextSwiftUIStyle { .init(fill: .linearGradient(.init(colors: [.pink, .orange])), stroke: .init(paint: .solid(.blue), width: 1)) }
    private var attributedText: AttributedString {
        var value = AttributedString("Bold green attributed marquee stays underlined and moves as one line.")
        value.font = .system(size: 18, weight: .bold); value.foregroundColor = .green; value.underlineStyle = .single
        return value
    }
}
