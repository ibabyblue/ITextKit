import ITextKit
import SwiftUI
import UIKit

struct StyledTextPerformanceView: View {
    @State private var isAtEnd = false

    private let style = ITextSwiftUIStyle(
        fill: .linearGradient(ITextLinearGradient(
            colors: [.cyan, .blue, .purple],
            startPoint: .leading,
            endPoint: .trailing
        )),
        stroke: ITextStroke(
            paint: .linearGradient(ITextLinearGradient(
                colors: [.yellow, .orange, .red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )),
            width: 1.5
        )
    )

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 12) {
                ForEach(0..<20, id: \.self) { index in
                    ITextStyledText(
                        "Styled row \(index) — gradient fill and stroke",
                        font: .systemFont(ofSize: 20, weight: .semibold),
                        style: style,
                        adjustsFontForContentSizeCategory: false
                    )
                    .lineLimit(1)
                    .accessibilityLabel("Styled row \(index)")
                }
            }
            .padding(.horizontal, 16)
            .offset(y: isAtEnd ? -420 : 20)
            .animation(
                .linear(duration: 6).repeatForever(autoreverses: true),
                value: isAtEnd
            )
            .frame(width: proxy.size.width, alignment: .top)
        }
        .clipped()
        .background(Color.black)
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("Styled performance fixture")
        }
        .onAppear {
            isAtEnd = true
        }
    }
}
