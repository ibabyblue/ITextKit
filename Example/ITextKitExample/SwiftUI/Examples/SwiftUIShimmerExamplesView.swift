import ITextKit
import SwiftUI
import UIKit

struct SwiftUIShimmerExamplesView: View {
    @State private var active = true
    var body: some View {
        SwiftUIDemoPage(title: DemoTopic.shimmer.swiftUITitle, summary: DemoTopic.shimmer.summary, capabilities: DemoTopic.shimmer.capabilities) {
            sample("swiftui.shimmer.plain", "Plain text", "Apply shimmer after text-rendering modifiers.", "Text(\"Plain shimmer\").font(.headline).shimmerText()") { Text("Plain shimmer").font(.headline).shimmerText(isActive: active) }
            sample("swiftui.shimmer.attributed", "Attributed text", "Native rich text remains the single accessibility owner.", "Text(attributedText).shimmerText()") { Text(richText).shimmerText(isActive: active) }
            sample("swiftui.shimmer.styled", "Styled fill + stroke", "Styled vector content composes directly with shimmer.", """
            ITextStyledText(
                "Styled shimmer",
                font: .systemFont(ofSize: 28, weight: .bold),
                style: .init(
                    fill: .linearGradient(.init(colors: [.pink, .orange])),
                    stroke: .init(paint: .linearGradient(.init(colors: [.white, .yellow])), width: 2)
                )
            )
            .shimmerText(isActive: isActive)
            """) { ITextStyledText("Styled shimmer", font: .systemFont(ofSize: 28, weight: .bold), style: style).shimmerText(isActive: active).padding(12).background(Color.black, in: RoundedRectangle(cornerRadius: 10)) }
            sample("swiftui.shimmer.configuration", "Configuration", "Control duration, band width, intensity, semantic direction, and highlight color.", "Text(\"Configured\").shimmerText(configuration: .init(duration: 1.2, bandWidth: 0.2, intensity: 0.9, direction: .trailingToLeading), highlight: .yellow)") { Text("Configured shimmer").shimmerText(isActive: active, configuration: .init(duration: 1.2, bandWidth: 0.2, intensity: 0.9, direction: .trailingToLeading), highlight: .yellow) }
            sample("swiftui.shimmer.order", "Correct modifier order", "Font and foreground go before shimmer; frame, padding, and background go after it.", "Text(\"Text only\").font(.headline).shimmerText().padding(16).background(Color.mint.opacity(0.14))") { Text("SwiftUI shimmer background probe").font(.headline).foregroundStyle(.secondary).shimmerText(isActive: active).frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Color.mint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12)) }
            sample("swiftui.shimmer.toggle", "Active state", "Turning shimmer off removes the decorative overlay without changing text.", "view.shimmerText(isActive: isActive)") { VStack(alignment: .leading) { Toggle("Shimmer active", isOn: $active); Text(active ? "Shimmer: On" : "Shimmer: Off") } }
        }
    }
    private func sample<Content: View>(_ id: String, _ title: String, _ summary: String, _ code: String, @ViewBuilder content: () -> Content) -> some View { SwiftUIDemoSection(snippet: .init(id: id, title: title, summary: summary, capabilities: [.plain, .attributed, .styled, .accessibility], code: code)) { content() } }
    private var style: ITextSwiftUIStyle { .init(fill: .linearGradient(.init(colors: [.pink, .orange])), stroke: .init(paint: .linearGradient(.init(colors: [.white, .yellow])), width: 2)) }
    private var richText: AttributedString { var value = AttributedString("Attributed shimmer"); value.font = .headline; value.foregroundColor = .indigo; value.underlineStyle = .single; return value }
}
