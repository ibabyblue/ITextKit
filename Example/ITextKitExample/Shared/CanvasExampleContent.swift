import ITextKit
import UIKit

/// Offline inputs shared by the two native canvas examples.
enum CanvasExampleContent {
    static let firstID = UUID(uuidString: "52E70000-0000-0000-0000-000000000001")!

    static var document: ITextCanvasDocument {
        .init(text: String(repeating: "在文字中摆放一张图片，长按后可以移动它，也可以用双指旋转。文字会沿着图片的边缘重新排列。\n\nFloating images keep their position relative to the text. Try editing this paragraph, moving a picture, and saving your layout. 👨‍👩‍👧‍👦\n\n", count: 5), images: [
            .init(id: firstID, resourceKey: "landscape", accessibilityLabel: "Mountain landscape", xRatio: 0.12, yOffset: 0.08, widthRatio: 0.38, aspectRatio: 1.25, rotationDegrees: -12),
            .init(resourceKey: "sunset", accessibilityLabel: "Sunset landscape", anchorOffset: 200, xRatio: 0.55, widthRatio: 0.35, aspectRatio: 1.25, rotationDegrees: 15)
        ])
    }

    /// Predecoded pictures; the provider is a lookup rather than work performed on gesture frames.
    static let pictures: [String: UIImage] = ["landscape": picture(sunset: false), "sunset": picture(sunset: true)]

    static let snippet = """
    let canvas = ITextCanvasView()
    canvas.imageProvider = { images[$0] }
    canvas.document = .init(text: body, images: [
        .init(resourceKey: "photo", widthRatio: 0.4,
              aspectRatio: 1.25, rotationDegrees: -12)
    ])
    canvas.onDocumentChange = { document in
        // Save text and geometry together.
        let data = try? JSONEncoder().encode(document)
    }
    """

    private static func picture(sunset: Bool) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 320, height: 256)).image { context in
            (sunset ? UIColor.systemOrange : UIColor.systemTeal).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 256))
            UIColor.systemYellow.setFill()
            UIBezierPath(ovalIn: CGRect(x: 220, y: 28, width: 62, height: 62)).fill()
            UIColor.white.withAlphaComponent(0.85).setFill()
            let mountain = UIBezierPath()
            mountain.move(to: CGPoint(x: 0, y: 240))
            mountain.addLine(to: CGPoint(x: 120, y: 60))
            mountain.addLine(to: CGPoint(x: 245, y: 240))
            mountain.close()
            mountain.fill()
            UIColor.systemIndigo.withAlphaComponent(0.65).setFill()
            let foreground = UIBezierPath()
            foreground.move(to: CGPoint(x: 80, y: 256))
            foreground.addLine(to: CGPoint(x: 245, y: 110))
            foreground.addLine(to: CGPoint(x: 320, y: 210))
            foreground.addLine(to: CGPoint(x: 320, y: 256))
            foreground.close()
            foreground.fill()
        }
    }
}
