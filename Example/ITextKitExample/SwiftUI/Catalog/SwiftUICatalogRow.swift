import SwiftUI

struct SwiftUICatalogRow: View {
    let topic: DemoTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(topic.swiftUITitle)
                .font(.headline)
            Text(topic.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(topic.capabilities.map(\.rawValue).joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 4)
    }
}
