import SwiftUI

struct UIKitExampleContainer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIKitExampleViewController {
        UIKitExampleViewController()
    }

    func updateUIViewController(
        _ uiViewController: UIKitExampleViewController,
        context: Context
    ) {}
}
