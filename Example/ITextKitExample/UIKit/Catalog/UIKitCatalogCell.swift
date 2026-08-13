import UIKit

final class UIKitCatalogCell: UITableViewCell {
    static let reuseIdentifier = "UIKitCatalogCell"

    func configure(topic: DemoTopic) {
        var configuration = defaultContentConfiguration()
        configuration.text = topic.uiKitTitle
        configuration.secondaryText = topic.summary + "\n"
            + topic.capabilities.map(\.rawValue).joined(separator: " · ")
        configuration.secondaryTextProperties.numberOfLines = 0
        contentConfiguration = configuration
        accessoryType = .disclosureIndicator
        accessibilityLabel = topic.uiKitTitle
        accessibilityHint = topic.summary
        accessibilityTraits = .button
        accessibilityIdentifier = "catalog.uikit.\(topic.id)"
    }
}
