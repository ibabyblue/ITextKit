import SwiftUI
import UIKit

struct SwiftUIDemoCodeBlock: View {
    let snippet: DemoSnippet

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Code")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(copied ? "Copied" : "Copy") {
                    UIPasteboard.general.string = snippet.code
                    copied = true
                }
                .font(.caption.weight(.semibold))
                .accessibilityLabel(copied ? "Copied" : "Copy \(snippet.title) code")
                .accessibilityIdentifier("copy.\(snippet.id)")
            }

            ScrollView(.horizontal, showsIndicators: true) {
                Text(snippet.code)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(12)
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(snippet.code)
            .accessibilityIdentifier("code.\(snippet.id)")
        }
    }
}
