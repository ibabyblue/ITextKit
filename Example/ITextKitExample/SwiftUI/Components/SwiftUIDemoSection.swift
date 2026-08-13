import SwiftUI

struct SwiftUIDemoSection<Content: View>: View {
    let snippet: DemoSnippet
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(snippet.title)
                .font(.headline)
            Text(snippet.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    Color(uiColor: .secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            SwiftUIDemoCodeBlock(snippet: snippet)
        }
    }
}
