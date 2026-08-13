import SwiftUI

struct SwiftUICatalogView: View {
    var body: some View {
        List(DemoTopic.allCases) { topic in
            NavigationLink {
                SwiftUITopicIntroductionView(topic: topic)
            } label: {
                SwiftUICatalogRow(topic: topic)
            }
            .accessibilityIdentifier("catalog.swiftui.\(topic.id)")
        }
        .navigationTitle("SwiftUI")
    }
}

private struct SwiftUITopicIntroductionView: View {
    let topic: DemoTopic

    var body: some View {
        SwiftUIDemoPage(
            title: topic.swiftUITitle,
            summary: topic.summary,
            capabilities: topic.capabilities
        ) {
            SwiftUIDemoSection(snippet: topic.introductionSnippet) {
                Text(topic.summary)
            }
        }
    }
}
