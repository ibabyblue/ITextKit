import ITextKit
import SwiftUI
import UIKit

struct SwiftUITypewriterExamplesView: View {
    @State private var generation = 0
    var body: some View {
        SwiftUIDemoPage(title: DemoTopic.typewriter.swiftUITitle, summary: DemoTopic.typewriter.summary, capabilities: DemoTopic.typewriter.capabilities) {
            sample("swiftui.typewriter.plain", "Plain input", "The ideal size grows with the revealed prefix.", "ITextTypewriter(text: \"A plain typewriter grows as it reveals.\")") { ITextTypewriter(text: "A plain typewriter grows as it reveals.").id(generation) }
            sample("swiftui.typewriter.attributed", "Attributed input", "AttributedString attributes appear with each complete character.", "ITextTypewriter(attributedText: richText)") { ITextTypewriter(attributedText: richText).id(generation) }
            sample("swiftui.typewriter.styled", "Styled input", "Styled content supports gradient fill and outward stroke.", """
            ITextTypewriter(
                text: "Styled typewriter",
                font: .systemFont(ofSize: 22, weight: .bold),
                textStyle: .init(
                    fill: .linearGradient(.init(colors: [.pink, .orange])),
                    stroke: .init(paint: .solid(.blue), width: 1)
                )
            )
            """) { ITextTypewriter(text: "Styled typewriter", font: .systemFont(ofSize: 22, weight: .bold), textStyle: style).id(generation) }
            sample("swiftui.typewriter.wrapping", "Wrapping and growth", "A proposed width allows natural multiline height without fixing component height.", "ITextTypewriter(text: message).frame(maxWidth: 280, alignment: .leading)") { ITextTypewriter(text: "This longer typewriter grows wider, wraps, and then grows taller.").frame(maxWidth: 280, alignment: .leading).id(generation) }
            sample("swiftui.typewriter.emoji", "Emoji stays whole", "Reveal boundaries use extended grapheme clusters.", "ITextTypewriter(text: \"Rich 👨‍👩‍👧‍👦 typewriter\")") { ITextTypewriter(text: "Rich 👨‍👩‍👧‍👦 typewriter").id(generation) }
            sample("swiftui.typewriter.replay", "Replay", "Change view identity to replay the value from an empty prefix.", "typewriterGeneration += 1") { Button("Replay Typewriter") { generation += 1 }.buttonStyle(.bordered) }
        }
    }
    private func sample<Content: View>(_ id: String, _ title: String, _ summary: String, _ code: String, @ViewBuilder content: () -> Content) -> some View { SwiftUIDemoSection(snippet: .init(id: id, title: title, summary: summary, capabilities: [.plain, .attributed, .styled, .dynamicType], code: code)) { content() } }
    private var style: ITextSwiftUIStyle { .init(fill: .linearGradient(.init(colors: [.pink, .orange])), stroke: .init(paint: .solid(.blue), width: 1)) }
    private var richText: AttributedString { var value = AttributedString("Rich attributed typewriter"); value.font = .headline; value.foregroundColor = .indigo; value.underlineStyle = .single; return value }
}
