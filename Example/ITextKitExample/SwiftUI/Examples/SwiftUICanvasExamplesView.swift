import ITextKit
import SwiftUI

/// The same native editor controlled through a document binding.
struct SwiftUICanvasExamplesView: View {
    @State private var document = CanvasExampleContent.document
    @State private var editable = true
    @State private var saved: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Long-press to move a picture. Rotate with two fingers. Edit the text and save the complete layout.")
                .font(.subheadline)
            HStack {
                Button("Add") {
                    document.images.append(.init(resourceKey: "sunset", anchorOffset: document.text.utf16.count / 2, widthRatio: 0.3, aspectRatio: 1.25))
                }.disabled(!editable)
                Button(editable ? "Read only" : "Edit") { editable.toggle() }
                Button("Save") { saved = try? JSONEncoder().encode(document) }
                Button("Restore") {
                    if let saved, let value = try? JSONDecoder().decode(ITextCanvasDocument.self, from: saved) { document = value }
                }.disabled(saved == nil)
            }
            Text("\(document.images.count) images · angle \(Int(document.images.first?.rotationDegrees ?? 0))°")
                .font(.caption.monospacedDigit())
                .accessibilityIdentifier("canvas.status")
            ITextCanvas(document: $document, isEditable: editable, imageProvider: { CanvasExampleContent.pictures[$0] })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            DisclosureGroup("SwiftUI code") {
                Text("ITextCanvas(document: $document, imageProvider: { images[$0] })\n    .frame(height: 500)")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .navigationTitle("Image Canvas")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Direct entry used by reproducible native UI interaction tests.
struct CanvasExampleHost: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { UIKitCanvasExamplesViewController() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
