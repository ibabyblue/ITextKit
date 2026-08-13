import SwiftUI

struct SwiftUICatalogView: View {
    var body: some View {
        List(DemoTopic.allCases) { topic in
            NavigationLink {
                destination(for: topic)
            } label: {
                SwiftUICatalogRow(topic: topic)
            }
            .accessibilityIdentifier("catalog.swiftui.\(topic.id)")
        }
        .navigationTitle("SwiftUI")
    }

    @ViewBuilder
    private func destination(for topic: DemoTopic) -> some View {
        switch topic {
        case .styled:
            SwiftUIStyledTextExamplesView()
        case .rotator:
            SwiftUIRotatorExamplesView()
        default:
            SwiftUITopicIntroductionView(topic: topic)
        }
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
