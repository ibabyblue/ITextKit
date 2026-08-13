import SwiftUI
import UIKit

struct _ITextStyledEffectConfiguration {
    let values: [NSAttributedString]
    let defaultFont: UIFont
    let style: ITextSwiftUIStyle
    let adjustsFont: Bool
}

@MainActor
struct _ITextStyledRotatorRepresentable: UIViewRepresentable {
    let content: _ITextStyledEffectConfiguration
    let configuration: ITextRotatorConfiguration
    let playbackState: ITextPlaybackState
    let onChange: ((Int, String) -> Void)?

    func makeUIView(context: Context) -> ITextRotatorView {
        ITextRotatorView(
            attributedTexts: content.values,
            configuration: configuration,
            playbackState: playbackState
        )
    }

    func updateUIView(_ view: ITextRotatorView, context: Context) {
        view.attributedTexts = content.values
        view.configuration = configuration
        view.font = content.defaultFont
        view.adjustsFontForContentSizeCategory = content.adjustsFont
        view.textStyle = ITextStyledText._resolvedUIKitStyle(content.style)
        view.onTextChange = onChange
        synchronize(playbackState, with: view)
    }
}

@MainActor
struct _ITextStyledMarqueeRepresentable: UIViewRepresentable {
    let content: _ITextStyledEffectConfiguration
    let configuration: ITextMarqueeConfiguration
    let playbackState: ITextPlaybackState

    func makeUIView(context: Context) -> ITextMarqueeView {
        let view = ITextMarqueeView(
            attributedText: content.values[0],
            configuration: configuration,
            playbackState: playbackState
        )
        view.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )
        return view
    }

    func updateUIView(_ view: ITextMarqueeView, context: Context) {
        let attributedText = content.values[0]
        if !view.attributedText.isEqual(to: attributedText) {
            view.attributedText = attributedText
        }
        if view.configuration != configuration {
            view.configuration = configuration
        }
        if view.font != content.defaultFont {
            view.font = content.defaultFont
        }
        if view.adjustsFontForContentSizeCategory != content.adjustsFont {
            view.adjustsFontForContentSizeCategory = content.adjustsFont
        }
        let style = ITextStyledText._resolvedUIKitStyle(content.style)
        if view.textStyle != style {
            view.textStyle = style
        }
        synchronize(playbackState, with: view)
    }

    @available(iOS 16.0, *)
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: ITextMarqueeView,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? CGFloat.greatestFiniteMagnitude
        let height = proposal.height ?? CGFloat.greatestFiniteMagnitude
        return uiView.sizeThatFits(CGSize(width: width, height: height))
    }
}

@MainActor
struct _ITextStyledTypewriterRepresentable: UIViewRepresentable {
    let content: _ITextStyledEffectConfiguration
    let configuration: ITextTypewriterConfiguration

    func makeUIView(context: Context) -> ITextTypewriterView {
        ITextTypewriterView(
            attributedText: content.values[0],
            configuration: configuration
        )
    }

    func updateUIView(_ view: ITextTypewriterView, context: Context) {
        view.attributedText = content.values[0]
        view.configuration = configuration
        view.font = content.defaultFont
        view.adjustsFontForContentSizeCategory = content.adjustsFont
        view.textStyle = ITextStyledText._resolvedUIKitStyle(content.style)
    }
}

@MainActor
private func synchronize(
    _ state: ITextPlaybackState,
    with view: ITextRotatorView
) {
    guard state != view.playbackState else { return }
    switch state {
    case .playing: view.start()
    case .paused: view.pause()
    case .stopped: view.stop()
    }
}

@MainActor
private func synchronize(
    _ state: ITextPlaybackState,
    with view: ITextMarqueeView
) {
    guard state != view.playbackState else { return }
    switch state {
    case .playing: view.start()
    case .paused: view.pause()
    case .stopped: view.stop()
    }
}
