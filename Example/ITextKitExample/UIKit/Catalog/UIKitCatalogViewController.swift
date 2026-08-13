import UIKit

final class UIKitCatalogViewController: UITableViewController {
    private let topics = DemoTopic.allCases

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit"
        tableView.register(
            UIKitCatalogCell.self,
            forCellReuseIdentifier: UIKitCatalogCell.reuseIdentifier
        )
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 96
    }

    override func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        topics.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: UIKitCatalogCell.reuseIdentifier,
            for: indexPath
        ) as! UIKitCatalogCell
        cell.configure(topic: topics[indexPath.row])
        return cell
    }

    override func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        let topic = topics[indexPath.row]
        navigationController?.pushViewController(
            viewController(for: topic),
            animated: true
        )
    }

    private func viewController(
        for topic: DemoTopic
    ) -> UIViewController {
        switch topic {
        case .styled:
            return UIKitStyledTextExamplesViewController()
        case .rotator:
            return UIKitRotatorExamplesViewController()
        case .marquee:
            return UIKitMarqueeExamplesViewController()
        case .typewriter:
            return UIKitTypewriterExamplesViewController()
        default:
            return UIKitDemoDetailViewController(topic: topic)
        }
    }
}
