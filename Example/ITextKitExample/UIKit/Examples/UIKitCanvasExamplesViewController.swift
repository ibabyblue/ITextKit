import ITextKit
import UIKit

/// A bounded native editor with persistent content, history, and read-only restoration.
final class UIKitCanvasExamplesViewController: UIViewController {
    private let canvas = ITextCanvasView()
    private let status = UILabel()
    private var saved: Data?
    private var edits = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Image Canvas"
        view.backgroundColor = .systemBackground
        let instructions = UILabel()
        instructions.text = "Long-press a picture to move it. Rotate with two fingers. Text follows the tilted edges."
        instructions.font = .preferredFont(forTextStyle: .subheadline)
        instructions.numberOfLines = 0
        status.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        status.numberOfLines = 0
        status.accessibilityIdentifier = "canvas.status"
        let toolbar = UIStackView(arrangedSubviews: [
            button("Add", id: "canvas.add") { [weak self] in
                guard let self else { return }
                self.canvas.insertImage(.init(resourceKey: "sunset", anchorOffset: self.canvas.document.text.utf16.count / 2, widthRatio: 0.3, aspectRatio: 1.25))
            },
            button("Undo", id: "canvas.undo") { [weak self] in self?.canvas.undo() },
            button("Redo", id: "canvas.redo") { [weak self] in self?.canvas.redo() },
            button("Read only", id: "canvas.mode") { [weak self] in
                guard let self else { return }
                self.canvas.isEditable.toggle()
                self.updateStatus()
            }
        ])
        toolbar.distribution = .fillEqually
        let persistence = UIStackView(arrangedSubviews: [
            button("Save", id: "canvas.save") { [weak self] in
                guard let self else { return }
                self.canvas.finishEditing()
                self.saved = try? JSONEncoder().encode(self.canvas.document)
                self.updateStatus()
            },
            button("Restore", id: "canvas.restore") { [weak self] in
                guard let self, let saved = self.saved, let document = try? JSONDecoder().decode(ITextCanvasDocument.self, from: saved) else { return }
                self.canvas.finishEditing()
                self.canvas.document = document
                self.updateStatus()
            },
            button("Code", id: "canvas.code") { [weak self] in
                let alert = UIAlertController(title: "UIKit", message: CanvasExampleContent.snippet, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Copy", style: .default) { _ in UIPasteboard.general.string = CanvasExampleContent.snippet })
                alert.addAction(UIAlertAction(title: "Close", style: .cancel))
                self?.present(alert, animated: true)
            }
        ])
        persistence.distribution = .fillEqually
        canvas.imageProvider = { CanvasExampleContent.pictures[$0] }
        canvas.document = CanvasExampleContent.document
        canvas.backgroundColor = .secondarySystemBackground
        canvas.layer.cornerRadius = 12
        canvas.clipsToBounds = true
        canvas.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)
        canvas.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        canvas.onDocumentChange = { [weak self] _ in self?.edits += 1; self?.updateStatus() }
        canvas.onImageTap = { [weak self] id in
            guard let self else { return }
            let alert = UIAlertController(title: "Image", message: "Rotate or remove the selected picture.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Rotate 15°", style: .default) { _ in
                guard let image = self.canvas.document.images.first(where: { $0.id == id }) else { return }
                self.canvas.rotateImage(id: id, to: image.rotationDegrees + 15)
            })
            alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { _ in self.canvas.removeImage(id: id) })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self.present(alert, animated: true)
        }
        let stack = UIStackView(arrangedSubviews: [instructions, toolbar, persistence, status, canvas])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8)
        ])
        updateStatus()
    }

    private func button(_ title: String, id: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.accessibilityIdentifier = id
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func updateStatus() {
        let angle = Int(canvas.document.images.first?.rotationDegrees ?? 0)
        status.text = "\(canvas.isEditable ? "Editing" : "Read only") · \(canvas.document.images.count) images · angle \(angle)° · edits \(edits)\(saved == nil ? "" : " · saved")"
    }
}
