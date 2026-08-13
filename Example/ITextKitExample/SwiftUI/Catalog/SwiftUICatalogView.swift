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
        case .marquee:
            SwiftUIMarqueeExamplesView()
        case .typewriter:
            SwiftUITypewriterExamplesView()
        case .shimmer:
            SwiftUIShimmerExamplesView()
        case .environment:
            SwiftUIEnvironmentExamplesView()
        }
    }
}
