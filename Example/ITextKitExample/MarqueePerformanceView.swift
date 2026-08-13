import ITextKit
import SwiftUI
import UIKit

struct MarqueePerformanceView: View {
    private let primaryStyle = ITextSwiftUIStyle(
        fill: .linearGradient(.init(
            colors: [.cyan, .blue, .purple]
        )),
        stroke: .init(
            paint: .linearGradient(.init(colors: [.yellow, .orange, .red])),
            width: 1.5
        )
    )

    private let secondaryStyle = ITextSwiftUIStyle(
        fill: .linearGradient(.init(
            colors: [.pink, .orange]
        )),
        stroke: .init(
            paint: .linearGradient(.init(colors: [.white, .blue])),
            width: 1
        )
    )

    private var attributedFixture: AttributedString {
        var value = AttributedString(
            "Attributed marquee — kerning and color stay on the compositor"
        )
        value.font = .system(size: 19, weight: .semibold)
        value.foregroundColor = .mint
        value.kern = 1.5
        return value
    }

    var body: some View {
        VStack(spacing: 18) {
            ITextMarquee(
                text: "Default plain marquee continuously crosses a narrow viewport"
            )
            .accessibilityLabel("Marquee row 0")

            ITextMarquee(attributedText: attributedFixture)
                .accessibilityLabel("Marquee row 1")

            ITextMarquee(
                text: "Gradient fill and gradient stroke marquee number one",
                font: .systemFont(ofSize: 20, weight: .bold),
                textStyle: primaryStyle,
                adjustsFontForContentSizeCategory: false
            )
            .accessibilityLabel("Marquee row 2")

            ITextMarquee(
                text: "Second styled marquee proves independent cached drawing",
                font: .systemFont(ofSize: 20, weight: .semibold),
                textStyle: secondaryStyle,
                adjustsFontForContentSizeCategory: false
            )
            .accessibilityLabel("Marquee row 3")

            ITextMarquee(
                text: "Configured forty point per second marquee remains smooth",
                configuration: .init(speed: 40, spacing: 32, initialDelay: 0)
            )
            .accessibilityLabel("Marquee row 4")

            ITextMarquee(
                text: "اتجاه من اليمين إلى اليسار يرث الحركة الصحيحة",
                configuration: .init(speed: 40, spacing: 24, initialDelay: 0)
            )
            .environment(\.layoutDirection, .rightToLeft)
            .accessibilityLabel("Marquee row 5")
        }
        .frame(width: 280)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .foregroundColor(.white)
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("Marquee performance fixture")
        }
    }
}
