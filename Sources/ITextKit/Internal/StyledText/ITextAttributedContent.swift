import UIKit

/// An immutable rich-text snapshot with defaults applied only to missing runs.
struct _ITextAttributedContent {
    let value: NSAttributedString

    init(
        source: NSAttributedString,
        defaultFont: UIFont,
        defaultColor: UIColor
    ) {
        let mutable = NSMutableAttributedString(attributedString: source)
        let fullRange = NSRange(location: 0, length: mutable.length)
        Self.applyDefault(
            .font,
            value: defaultFont,
            to: mutable,
            in: fullRange
        )
        Self.applyDefault(
            .foregroundColor,
            value: defaultColor,
            to: mutable,
            in: fullRange
        )
        value = NSAttributedString(attributedString: mutable)
    }

    private static func applyDefault(
        _ key: NSAttributedString.Key,
        value: Any,
        to text: NSMutableAttributedString,
        in fullRange: NSRange
    ) {
        var missingRanges: [NSRange] = []
        text.enumerateAttribute(key, in: fullRange) { existing, range, _ in
            if existing == nil {
                missingRanges.append(range)
            }
        }
        for range in missingRanges {
            text.addAttribute(key, value: value, range: range)
        }
    }
}
