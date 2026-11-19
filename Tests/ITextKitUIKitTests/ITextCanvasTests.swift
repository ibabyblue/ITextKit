import UIKit
import XCTest
@testable import ITextKit

@MainActor
final class ITextCanvasTests: XCTestCase {
    func testDocumentRoundTripAndRepeatedResourceIdentity() throws {
        let first = ITextCanvasImage(resourceKey: "same", anchorOffset: 4, rotationDegrees: 35)
        let second = ITextCanvasImage(resourceKey: "same", xRatio: 0.6, widthRatio: 0.2)
        let value = ITextCanvasDocument(text: "A👨‍👩‍👧‍👦\n中文", images: [first, second])
        let decoded = try JSONDecoder().decode(ITextCanvasDocument.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(decoded, value)
        let view = canvas(value)
        XCTAssertEqual(view.document.images.count, 2)
        XCTAssertNotNil(view.imageRect(id: first.id))
        XCTAssertNotNil(view.imageRect(id: second.id))
    }

    func testRotatedPathFollowsCornersRatherThanBoundingBox() {
        let pose = _ITextCanvasPlacement(frame: CGRect(x: 60, y: 60, width: 120, height: 80), angle: .pi / 4)
        let exact = pose.path(clearance: 6, wrapping: .rotatedRectangle)
        let box = pose.path(clearance: 6, wrapping: .boundingBox)
        let corner = CGPoint(x: pose.bounds().minX + 1, y: pose.bounds().minY + 1)
        XCTAssertFalse(exact.contains(corner))
        XCTAssertTrue(box.contains(corner))
        XCTAssertTrue(exact.contains(CGPoint(x: pose.frame.midX, y: pose.frame.midY)))
    }

    func testManipulationIsOneUndoableTransactionAndCancellationRestores() {
        let image = ITextCanvasImage(resourceKey: "a", yOffset: 0.15, widthRatio: 0.25)
        let initial = ITextCanvasDocument(text: String(repeating: "Text 中文 words. ", count: 50), images: [image])
        let view = canvas(initial)
        var changes = 0
        var ownership: [Bool] = []
        view.onDocumentChange = { _ in changes += 1 }
        view.onInteractionChange = { ownership.append($0) }
        let generation = view.baseline.generation
        view.beginManipulation(id: image.id)
        for frame in 1...60 {
            view.updateManipulation(translation: CGPoint(x: frame / 3, y: frame / 2), rotation: CGFloat(frame) * .pi / 180)
            view.layoutIfNeeded()
        }
        XCTAssertEqual(view.document, initial, "Live geometry must not publish partial document transactions")
        XCTAssertEqual(changes, 0)
        XCTAssertEqual(view.baseline.generation, generation)
        view.endManipulation(cancelled: false)
        let committed = view.document
        XCTAssertEqual(committed.images[0].rotationDegrees, 60, accuracy: 0.01)
        XCTAssertEqual(changes, 1)
        XCTAssertEqual(ownership, [true, false])
        view.undo()
        XCTAssertEqual(view.document, initial)
        view.redo()
        XCTAssertEqual(view.document, committed)
        view.beginManipulation(id: image.id)
        view.updateManipulation(translation: CGPoint(x: -30, y: 100), rotation: 1)
        view.endManipulation(cancelled: true)
        XCTAssertEqual(view.document, committed)
        XCTAssertTrue(view.textView.isScrollEnabled)
    }

    func testCollisionRejectsPoseWithoutMovingOtherImages() {
        let a = ITextCanvasImage(resourceKey: "a", xRatio: 0.05, yOffset: 0.1, widthRatio: 0.25)
        let b = ITextCanvasImage(resourceKey: "b", xRatio: 0.65, yOffset: 0.1, widthRatio: 0.25)
        let view = canvas(.init(text: "Body", images: [a, b]))
        let before = view.document
        view.beginManipulation(id: a.id)
        view.updateManipulation(translation: CGPoint(x: view.baseline.width * 0.6, y: 0), rotation: 0)
        view.endManipulation(cancelled: false)
        XCTAssertEqual(view.document, before)
    }

    func testReadonlyAndImageRemovalReleaseScrollOwnership() {
        let image = ITextCanvasImage(resourceKey: "a")
        let parent = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        let view = canvas(.init(text: "Body", images: [image]))
        parent.addSubview(view)
        view.beginManipulation(id: image.id)
        XCTAssertFalse(parent.isScrollEnabled)
        view.removeImage(id: image.id)
        XCTAssertTrue(parent.isScrollEnabled)
        XCTAssertTrue(view.document.images.isEmpty)
        view.undo()
        view.isEditable = false
        view.rotateImage(id: image.id, to: 80)
        XCTAssertEqual(view.document.images[0].rotationDegrees, 0)
        XCTAssertFalse(view.insertImage(.init(resourceKey: "b")))
    }

    func testInputAnchorsAndDocumentUndoRestoreDeletedAnchor() {
        let text = "Hello 👨‍👩‍👧‍👦 world\nEnd"
        let image = ITextCanvasImage(resourceKey: "a", anchorOffset: ("Hello 👨‍👩‍👧‍👦 " as NSString).length)
        let initial = ITextCanvasDocument(text: text, images: [image])
        let view = canvas(initial)
        view.textView.selectedRange = NSRange(location: 0, length: ("Hello 👨‍👩‍👧‍👦 " as NSString).length)
        view.textView.insertText("")
        XCTAssertEqual(view.document.text, "world\nEnd")
        XCTAssertEqual(view.document.images[0].anchorOffset, 0)
        view.undo()
        XCTAssertEqual(view.document, initial)
        view.redo()
        XCTAssertEqual(view.document.text, "world\nEnd")
    }

    func testMarkedTextSurvivesEqualEchoAndCommitsAsOneEdit() {
        let initial = ITextCanvasDocument(text: "Before ")
        let view = canvas(initial)
        view.textView.selectedRange = NSRange(location: initial.text.utf16.count, length: 0)
        view.textView.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))
        view.textViewDidChange(view.textView)
        XCTAssertNotNil(view.textView.markedTextRange)
        view.document = initial
        XCTAssertNotNil(view.textView.markedTextRange)
        view.textView.setMarkedText("你", selectedRange: NSRange(location: 1, length: 0))
        view.textViewDidChange(view.textView)
        view.textView.unmarkText()
        view.textViewDidChange(view.textView)
        XCTAssertEqual(view.document.text, "Before 你")
        view.undo()
        XCTAssertEqual(view.document, initial)
    }

    func testImageReloadDoesNotRebuildBaselineOrChangeSelection() {
        let image = ITextCanvasImage(resourceKey: "a", aspectRatio: 2)
        let view = canvas(.init(text: "Hello there", images: [image]))
        var loads = 0
        view.imageProvider = { _ in loads += 1; return UIImage(systemName: "photo") }
        view.textView.selectedRange = NSRange(location: 2, length: 3)
        let generation = view.baseline.generation
        let height = view.contentHeight
        view.beginManipulation(id: image.id)
        for angle in 0..<30 { view.updateManipulation(translation: .zero, rotation: CGFloat(angle) / 100); view.layoutIfNeeded() }
        XCTAssertEqual(loads, 1)
        view.endManipulation(cancelled: true)
        view.reloadImages()
        view.layoutIfNeeded()
        XCTAssertEqual(loads, 2)
        XCTAssertEqual(view.baseline.generation, generation)
        XCTAssertEqual(view.textView.selectedRange, NSRange(location: 2, length: 3))
        XCTAssertEqual(view.contentHeight, height)
    }

    func testViewportChangesDoNotRewriteDocumentAndReaderMatchesEditor() {
        let images = (0..<6).map { ITextCanvasImage(resourceKey: "\($0)", anchorOffset: $0 * 60, xRatio: $0.isMultiple(of: 2) ? 0.05 : 0.6, widthRatio: 0.3, aspectRatio: 1.4, rotationDegrees: Double($0) * 13) }
        let initial = ITextCanvasDocument(text: String(repeating: "环绕文字 👨‍👩‍👧‍👦 office العربية\n", count: 30), images: images)
        let editor = canvas(initial)
        let reader = canvas(initial)
        reader.isEditable = false
        for width: CGFloat in [320, 375, 390, 430, 768] {
            for view in [editor, reader] { view.frame.size.width = width; view.setNeedsLayout(); view.layoutIfNeeded() }
            XCTAssertEqual(editor.document, initial)
            XCTAssertEqual(editor.placements, reader.placements)
            XCTAssertEqual(editor.contentHeight, reader.contentHeight)
            XCTAssertEqual(editor.textView.layoutManager.glyphRange(for: editor.textView.textContainer).length, editor.textView.layoutManager.numberOfGlyphs)
            for pose in editor.placements {
                XCTAssertGreaterThanOrEqual(pose.bounds().minX, -0.01)
                XCTAssertLessThanOrEqual(pose.bounds().maxX, editor.baseline.width + 0.01)
            }
        }
    }

    func testEmptyImageTailAndInvalidGeometryRemainFinite() {
        let image = ITextCanvasImage(resourceKey: "a", xRatio: .nan, yOffset: 3, widthRatio: .infinity, aspectRatio: 0, rotationDegrees: .nan)
        let view = canvas(.init(images: [image]))
        XCTAssertTrue(view.contentHeight.isFinite)
        XCTAssertGreaterThan(view.contentHeight, view.bounds.height)
        XCTAssertGreaterThanOrEqual(view.textView.contentSize.height, view.contentHeight)
        view.document = .init(text: "Short")
        view.layoutIfNeeded()
        XCTAssertLessThan(view.contentHeight, 100)
        XCTAssertTrue(view.textView.textContainer.exclusionPaths.isEmpty)
    }

    func testNoOpLayoutDoesNotInvalidateExclusions() {
        let view = canvas(.init(text: "Body", images: [.init(resourceKey: "a")]))
        let baseline = view.baseline.generation
        let exclusions = view.exclusionGeneration
        for _ in 0..<100 { view.document = view.document; view.setNeedsLayout(); view.layoutIfNeeded() }
        XCTAssertEqual(view.baseline.generation, baseline)
        XCTAssertEqual(view.exclusionGeneration, exclusions)
    }

    func testGestureCommitKeepsLastRenderedLayout() {
        let image = ITextCanvasImage(resourceKey: "a", xRatio: 0.2, yOffset: 0.1, widthRatio: 0.3)
        let view = canvas(.init(text: String(repeating: "Wrapping 中文\n", count: 40), images: [image]))
        view.beginManipulation(id: image.id)
        view.updateManipulation(translation: CGPoint(x: 13.7, y: 25.3), rotation: 0.37)
        view.layoutIfNeeded()
        let generation = view.exclusionGeneration
        view.endManipulation(cancelled: false)
        view.layoutIfNeeded()
        XCTAssertEqual(view.exclusionGeneration, generation, "Committing an already displayed pose should not reflow text again")
    }

    func testIncrementalWrappingMatchesFreshLayoutAcrossMovementAndRotation() {
        let body = String(repeating: "中文 mixed العربية 👨‍👩‍👧‍👦 long words and wrapping.\n", count: 40)
        let image = ITextCanvasImage(resourceKey: "a", xRatio: 0.2, yOffset: 0.2, widthRatio: 0.35, aspectRatio: 1.5)
        let view = canvas(.init(text: body, images: [image]))
        for step in 0..<12 {
            view.beginManipulation(id: image.id)
            view.updateManipulation(translation: CGPoint(x: step.isMultiple(of: 2) ? 8 : -8, y: step < 6 ? 35 : -35), rotation: .pi / 12)
            view.layoutIfNeeded()
            view.endManipulation(cancelled: false)
            view.layoutIfNeeded()
            let fresh = canvas(view.document)
            XCTAssertEqual(view.contentHeight, fresh.contentHeight, accuracy: 0.5, "Step \(step)")
            let manager = view.textView.layoutManager
            let other = fresh.textView.layoutManager
            XCTAssertEqual(manager.numberOfGlyphs, other.numberOfGlyphs)
            for glyph in stride(from: 0, to: manager.numberOfGlyphs, by: 13) {
                XCTAssertEqual(manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil), other.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil), "Glyph \(glyph), step \(step)")
            }
        }
    }

    func testGlyphsStayOutsideRotatedPicturesInLTRAndRTL() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        let controller = UIViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        for body in [String(repeating: "中文 English 👨‍👩‍👧‍👦 mixed words.\n", count: 15), String(repeating: "العربية نص طويل يلتف حول الصورة.\n", count: 15)] {
            for angle in [0.0, 30, 45, 90, 135, 270] {
                let image = ITextCanvasImage(resourceKey: "a", xRatio: 0.3, yOffset: 0.2, widthRatio: 0.35, aspectRatio: 1.4, rotationDegrees: angle)
                let view = canvas(.init(text: body, images: [image]))
                controller.view.addSubview(view)
                view.setNeedsLayout()
                view.layoutIfNeeded()
                defer { view.removeFromSuperview() }
                let pose = view.placements[0]
                let manager = view.textView.layoutManager
                XCTAssertEqual(manager.glyphRange(for: view.textView.textContainer).length, manager.numberOfGlyphs)
                // Render text alone: placeholder image views must not hide an overlapping glyph.
                // Color/ligature glyph boundingRect queries can include non-ink run bounds.
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1
                format.opaque = true
                format.preferredRange = .standard
                let bitmap = UIGraphicsImageRenderer(size: CGSize(width: 390, height: 500), format: format).image { context in
                    UIColor.white.setFill()
                    context.fill(CGRect(x: 0, y: 0, width: 390, height: 500))
                    manager.drawGlyphs(forGlyphRange: NSRange(location: 0, length: manager.numberOfGlyphs), at: .zero)
                }
                let cgImage = bitmap.cgImage!
                // Normalize grayscale/color/emoji renderings into the same explicit RGBA layout.
                var bytes = [UInt8](repeating: 255, count: 390 * 500 * 4)
                bytes.withUnsafeMutableBytes { buffer in
                    let context = CGContext(data: buffer.baseAddress, width: 390, height: 500, bitsPerComponent: 8, bytesPerRow: 390 * 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 390, height: 500))
                }
                let interior = pose.path(clearance: -2, wrapping: .rotatedRectangle)
                let bounds = interior.bounds.integral.intersection(CGRect(x: 0, y: 0, width: 390, height: 500))
                var inkPixels = 0
                for y in Int(bounds.minY)..<Int(bounds.maxY) {
                    for x in Int(bounds.minX)..<Int(bounds.maxX) where interior.contains(CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)) {
                        let offset = y * 390 * 4 + x * 4
                        if bytes[offset] < 200 || bytes[offset + 1] < 200 || bytes[offset + 2] < 200 { inkPixels += 1 }
                    }
                }
                if inkPixels > 0 || angle == 0 {
                    let attachment = XCTAttachment(image: bitmap)
                    attachment.name = "Native text wrapping \(body.prefix(6)) angle \(angle)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                XCTAssertEqual(inkPixels, 0, "Visible text overlaps image interior at angle \(angle), \(body.prefix(6))")
                XCTAssertGreaterThanOrEqual(view.contentHeight, view.configuration.font.lineHeight * 15, "Every paragraph must advance to a new row")
            }
        }
    }

    func testCanvasReleasesAfterHistoryAndGestureCancellation() {
        weak var released: ITextCanvasView?
        autoreleasepool {
            let image = ITextCanvasImage(resourceKey: "a")
            let view = canvas(.init(text: "Body", images: [image]))
            released = view
            view.rotateImage(id: image.id, to: 35)
            view.beginManipulation(id: image.id)
            view.endManipulation(cancelled: true)
            view.undo()
            view.redo()
        }
        XCTAssertNil(released)
    }

    private func canvas(_ document: ITextCanvasDocument) -> ITextCanvasView {
        let view = ITextCanvasView(frame: CGRect(x: 0, y: 0, width: 390, height: 500))
        view.document = document
        view.layoutIfNeeded()
        return view
    }
}
