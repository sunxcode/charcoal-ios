//
//  Copyright © FINN.no AS, Inc. All rights reserved.
//

import FilterKit
import UIKit

// MARK: - DemoViewsTableViewController

class DemoViewsTableViewController: UITableViewController {
    init() {
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("") }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let indexPath = Sections.lastSelectedIndexPath {
            let viewController = Sections.viewController(for: indexPath)
            presentViewControllerWithDismissGesture(viewController)
        }
    }

    private func setup() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = UIColor.secondaryBlue
        tableView.delegate = self
        tableView.separatorStyle = .none
    }
}

// MARK: - UITableViewDelegate

extension DemoViewsTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Sections.all.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = Sections.all[section]
        return section.numberOfItems
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = Sections.formattedName(for: indexPath)
        cell.textLabel?.font = UIFont.title3
        cell.textLabel?.textColor = UIColor.milk
        cell.selectionStyle = .none
        cell.backgroundColor = .clear

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        Sections.lastSelectedIndexPath = indexPath
        let viewController = Sections.viewController(for: indexPath)
        presentViewControllerWithDismissGesture(viewController)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Sections.formattedName(for: section)
    }
}

extension DemoViewsTableViewController {
    func presentViewControllerWithDismissGesture(_ viewController: UIViewController) {
        self.present(viewController, animated: true) {
            let dismissGesture = UITapGestureRecognizer(target: self, action: #selector(self.closeCurrentlyPresentedViewController))
            dismissGesture.numberOfTapsRequired = 2
            viewController.view.addGestureRecognizer(dismissGesture)
        }
    }

    @objc func closeCurrentlyPresentedViewController() {
        Sections.lastSelectedIndexPath = nil
        dismiss(animated: true, completion: nil)
    }
}