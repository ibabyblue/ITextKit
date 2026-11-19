import SwiftUI
import UIKit

/// A SwiftUI adapter for the native editable image-wrapping canvas.
///
/// Give this view a bounded height; it scrolls internally. Equal binding updates preserve the
/// underlying text selection and marked input. Image geometry is published once per completed
/// gesture. Use the UIKit view for externally scrolled, intrinsic-height layouts.
@MainActor
public struct ITextCanvas: UIViewRepresentable {
    /// Complete document exchanged with the caller.
    @Binding private var document: ITextCanvasDocument

    /// Whether text and images can be edited.
    private var isEditable: Bool

    /// Shared native configuration.
    private var configuration: ITextCanvasConfiguration

    /// Caller-owned decoded-image lookup.
    private var imageProvider: (String) -> UIImage?

    /// Change token for asynchronous image loading; unrelated state updates do not reload images.
    private var imageRevision: Int

    /// Optional interaction and image-activation callbacks.
    private var onInteractionChange: ((Bool) -> Void)?
    private var onImageTap: ((UUID) -> Void)?

    /// Creates an editable or read-only canvas sharing UIKit's layout and gestures.
    /// - Parameters:
    ///   - document: Complete text and image placements; gesture changes commit on release.
    ///   - isEditable: Whether editing and image manipulation are enabled.
    ///   - configuration: Typography, spacing, wrapping, and collision behavior.
    ///   - imageRevision: Increment after asynchronously loading/replacing decoded images.
    ///   - imageProvider: Fast main-thread lookup; return nil for a stable placeholder.
    ///   - onInteractionChange: Receives the beginning and end of image manipulation.
    ///   - onImageTap: Receives the activated image placement ID.
    public init(
        document: Binding<ITextCanvasDocument>, isEditable: Bool = true,
        configuration: ITextCanvasConfiguration = .init(), imageRevision: Int = 0,
        imageProvider: @escaping (String) -> UIImage?,
        onInteractionChange: ((Bool) -> Void)? = nil, onImageTap: ((UUID) -> Void)? = nil
    ) {
        _document = document
        self.isEditable = isEditable
        self.configuration = configuration
        self.imageRevision = imageRevision
        self.imageProvider = imageProvider
        self.onInteractionChange = onInteractionChange
        self.onImageTap = onImageTap
    }

    /// Owns current callbacks without rebuilding the native editor.
    public final class Coordinator {
        /// Most recent SwiftUI value and image-loading revision.
        fileprivate var parent: ITextCanvas
        fileprivate var revision: Int

        /// Captures the initial value before the native view is created.
        fileprivate init(_ parent: ITextCanvas) { self.parent = parent; revision = parent.imageRevision }
    }

    /// Creates callback storage for this view identity.
    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// Creates one native canvas and installs stable callback bridges.
    public func makeUIView(context: Context) -> ITextCanvasView {
        let view = ITextCanvasView()
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        let coordinator = context.coordinator
        view.imageProvider = { [weak coordinator] in coordinator?.parent.imageProvider($0) }
        view.onDocumentChange = { [weak coordinator] value in coordinator?.parent.document = value }
        view.onInteractionChange = { [weak coordinator] value in coordinator?.parent.onInteractionChange?(value) }
        view.onImageTap = { [weak coordinator] id in coordinator?.parent.onImageTap?(id) }
        return view
    }

    /// Applies only changed values, preserving native composition and active image transactions.
    public func updateUIView(_ view: ITextCanvasView, context: Context) {
        context.coordinator.parent = self
        view.configuration = configuration
        view.isEditable = isEditable
        view.document = document
        if context.coordinator.revision != imageRevision {
            context.coordinator.revision = imageRevision
            view.reloadImages()
        }
    }

    /// Accepts a bounded SwiftUI viewport, including the smaller proposal when a keyboard appears.
    @available(iOS 16.0, *)
    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: ITextCanvasView, context: Context) -> CGSize? {
        let width = proposal.width.flatMap { $0.isFinite ? max(0, $0) : nil } ?? 320
        let height = proposal.height.flatMap { $0.isFinite ? max(0, $0) : nil } ?? 320
        return CGSize(width: width, height: height)
    }

    /// Releases gesture and keyboard ownership when the SwiftUI identity is removed.
    public static func dismantleUIView(_ uiView: ITextCanvasView, coordinator: Coordinator) {
        uiView.endManipulation(cancelled: true)
        uiView.onDocumentChange = nil
        uiView.finishEditing()
    }
}
