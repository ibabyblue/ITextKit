enum DemoTopic: String, CaseIterable, Identifiable {
    case styled
    case rotator
    case marquee
    case typewriter
    case shimmer
    case environment

    var id: String { rawValue }

    var swiftUITitle: String {
        switch self {
        case .styled: return "Styled Text"
        case .rotator: return "Rotator"
        case .marquee: return "Marquee"
        case .typewriter: return "Typewriter"
        case .shimmer: return "Shimmer"
        case .environment: return "Accessibility & Environment"
        }
    }

    var uiKitTitle: String {
        switch self {
        case .styled: return "Styled Label"
        case .rotator: return "Rotator View"
        case .marquee: return "Marquee View"
        case .typewriter: return "Typewriter View"
        case .shimmer: return "Shimmer Label"
        case .environment: return "Accessibility & Environment"
        }
    }

    var summary: String {
        switch self {
        case .styled:
            return "Fill and outline text with solid or linear-gradient paint."
        case .rotator:
            return "Rotate through plain, rich, or styled text at its natural height."
        case .marquee:
            return "Keep fitting text static and loop one overflowing line."
        case .typewriter:
            return "Reveal complete characters while intrinsic size grows."
        case .shimmer:
            return "Sweep a decorative highlight over real accessible text."
        case .environment:
            return "Inspect direction, Dynamic Type, and accessibility behavior."
        }
    }

    var capabilities: [DemoCapability] {
        switch self {
        case .styled:
            return [.plain, .attributed, .styled, .rtl, .dynamicType]
        case .rotator:
            return [.plain, .attributed, .styled, .playback, .dynamicType]
        case .marquee:
            return [.plain, .attributed, .styled, .playback, .rtl]
        case .typewriter:
            return [.plain, .attributed, .styled, .dynamicType]
        case .shimmer:
            return [.plain, .attributed, .styled, .accessibility]
        case .environment:
            return [.rtl, .dynamicType, .accessibility]
        }
    }

    var introductionSnippet: DemoSnippet {
        DemoSnippet(
            id: "\(rawValue).import",
            title: "Import ITextKit",
            summary: "Every example uses the same package product and module.",
            capabilities: capabilities,
            code: "import ITextKit"
        )
    }
}
