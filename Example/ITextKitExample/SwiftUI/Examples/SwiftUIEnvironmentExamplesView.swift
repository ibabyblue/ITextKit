import ITextKit
import SwiftUI

struct SwiftUIEnvironmentExamplesView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        SwiftUIDemoPage(title: DemoTopic.environment.swiftUITitle, summary: DemoTopic.environment.summary, capabilities: DemoTopic.environment.capabilities) {
            sample("swiftui.environment.ltr", "Left to right", "Force only this specimen to LTR.", "view.environment(\\.layoutDirection, .leftToRight)") { ITextMarquee(text: "Left-to-right semantic leading", playbackState: .paused).environment(\.layoutDirection, .leftToRight) }
            sample("swiftui.environment.rtl", "Right to left", "Force only this specimen to RTL so semantic directions mirror.", "view.environment(\\.layoutDirection, .rightToLeft)") { ITextMarquee(text: "مرحبا بالعالم من اليمين إلى اليسار", playbackState: .paused).environment(\.layoutDirection, .rightToLeft) }
            sample("swiftui.environment.dynamicType", "Dynamic Type", "Compare a normal and accessibility content-size environment.", """
            view.environment(\\.dynamicTypeSize, .large)
            view.environment(\\.dynamicTypeSize, .accessibility3)
            """) { VStack(alignment: .leading, spacing: 8) { Text("Large preferred text").font(.body).environment(\.dynamicTypeSize, .large); Text("Accessibility 3 preferred text").font(.body).environment(\.dynamicTypeSize, .accessibility3) } }
            sample("swiftui.environment.reduceMotion", "Reduce Motion", "This reports the real system environment and does not mutate it.", "@Environment(\\.accessibilityReduceMotion) var reduceMotion") { Text("System Reduce Motion: \(reduceMotion ? "On" : "Off")") }
            sample("swiftui.environment.voiceOver", "VoiceOver", "Each effect remains one accessibility owner; validate real navigation with VoiceOver enabled in Settings.", ".accessibilityLabel(fullLocalizedText)") { ITextStyledText("One accessible text element", style: .init(fill: .solid(.blue))).accessibilityLabel("One accessible text element") }
        }
    }
    private func sample<Content: View>(_ id: String, _ title: String, _ summary: String, _ code: String, @ViewBuilder content: () -> Content) -> some View { SwiftUIDemoSection(snippet: .init(id: id, title: title, summary: summary, capabilities: [.rtl, .dynamicType, .accessibility], code: code)) { content() } }
}
