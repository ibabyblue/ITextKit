import SwiftUI

struct SwiftUIDemoPage<Content: View>: View {
    let title: String
    let summary: String
    let capabilities: [DemoCapability]
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                    capabilityTags
                    content
                }
                .frame(
                    width: max(geometry.size.width - 40, 0),
                    alignment: .leading
                )
                .padding(20)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var capabilityTags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(capabilities, id: \.self) { capability in
                    Text(capability.rawValue)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }
        }
    }
}
