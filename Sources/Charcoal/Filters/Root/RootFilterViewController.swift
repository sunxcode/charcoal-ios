//
//  Copyright © FINN.no AS, Inc. All rights reserved.
//

import UIKit

protocol RootFilterViewControllerDelegate: class {
    func rootFilterViewControllerDidResetAllFilters(_ viewController: RootFilterViewController)
    func rootFilterViewController(_ viewController: RootFilterViewController, didRemoveFilter filter: Filter)
    func rootFilterViewController(_ viewController: RootFilterViewController, didSelectVerticalAt index: Int)
}

final class RootFilterViewController: FilterViewController {

    // MARK: - Internal properties

    var verticals: [Vertical]?

    weak var rootDelegate: (RootFilterViewControllerDelegate & FilterViewControllerDelegate)? {
        didSet { delegate = rootDelegate }
    }

    weak var freeTextFilterDelegate: FreeTextFilterDelegate?
    weak var freeTextFilterDataSource: FreeTextFilterDataSource?

    // MARK: - Private properties

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(FreeTextFilterCell.self)
        tableView.register(InlineFilterCell.self)
        tableView.register(RootFilterCell.self)
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private lazy var resetButton: UIBarButtonItem = {
        let action = #selector(handleResetButtonTap)
        let button = UIBarButtonItem(title: "reset".localized(), style: .plain, target: self, action: action)
        button.setTitleTextAttributes([.font: UIFont.title4])
        return button
    }()

    private var freeTextFilterViewController: FreeTextFilterViewController?
    private var indexPathsToReset: [IndexPath: Bool] = [:]

    // MARK: - Filter

    private var filter: Filter

    // MARK: - Init

    init(filter: Filter, selectionStore: FilterSelectionStore) {
        self.filter = filter
        super.init(title: filter.title, selectionStore: selectionStore)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = resetButton

        showBottomButton(true, animated: false)
        updateBottomButtonTitle()
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomButton.height, right: 0)
        setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    // MARK: - Public

    func reloadFilters() {
        tableView.reloadData()
    }

    // MARK: - Setup

    func set(filter: Filter, verticals: [Vertical]?) {
        self.filter = filter
        self.verticals = verticals
        navigationItem.title = filter.title
        updateBottomButtonTitle()
        tableView.reloadData()
    }

    private func setup() {
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func updateBottomButtonTitle() {
        let localizedString = String(format: "showResultsButton".localized(), filter.numberOfResults)
        let title = localizedString.replacingOccurrences(of: "\(filter.numberOfResults)", with: filter.formattedNumberOfResults)
        bottomButton.buttonTitle = title
    }

    // MARK: - Actions

    @objc private func handleResetButtonTap() {
        selectionStore.removeValues(for: filter)
        rootDelegate?.rootFilterViewControllerDidResetAllFilters(self)
        freeTextFilterViewController?.searchBar.text = nil

        for (index, subfilter) in filter.subfilters.enumerated() where subfilter.kind == .inline {
            let indexPath = IndexPath(row: index, section: 0)
            indexPathsToReset[indexPath] = true
        }

        tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
        tableView.layoutIfNeeded()
        tableView.reloadData()
    }
}

extension RootFilterViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filter.subfilters.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let currentFilter = filter.subfilters[indexPath.row]

        switch currentFilter.kind {
        case .search:
            freeTextFilterViewController =
                freeTextFilterViewController ??
                FreeTextFilterViewController(filter: currentFilter, selectionStore: selectionStore)

            freeTextFilterViewController?.delegate = self
            freeTextFilterViewController?.filterDelegate = freeTextFilterDelegate
            freeTextFilterViewController?.filterDataSource = freeTextFilterDataSource

            let cell = tableView.dequeue(FreeTextFilterCell.self, for: indexPath)
            cell.configure(with: freeTextFilterViewController!.searchBar)
            return cell
        case .inline:
            let vertical = verticals?.first(where: { $0.isCurrent })
            let segmentTitles = currentFilter.subfilters.map({ $0.subfilters.map({ $0.title }) })

            let selectedItems = currentFilter.subfilters.map({
                $0.subfilters.enumerated().compactMap({ index, filter in
                    self.selectionStore.isSelected(filter) ? index : nil
                })
            })

            let cell = tableView.dequeue(InlineFilterCell.self, for: indexPath)
            cell.delegate = self

            cell.configure(withTitles: segmentTitles, verticalTitle: vertical?.title, selectedItems: selectedItems)

            if indexPathsToReset[indexPath] == true {
                indexPathsToReset.removeValue(forKey: indexPath)
                cell.resetContentOffset()
            }

            return cell
        default:
            let titles = selectionStore.titles(for: currentFilter)
            let isValid = selectionStore.isValid(currentFilter)
            let cell = tableView.dequeue(RootFilterCell.self, for: indexPath)

            cell.delegate = self
            cell.configure(withTitle: currentFilter.title, selectionTitles: titles, isValid: isValid, style: currentFilter.style)

            cell.isEnabled = !selectionStore.hasSelectedSubfilters(for: filter, where: {
                currentFilter.mutuallyExclusiveFilterKeys.contains($0.key)
            })

            cell.isSeparatorHidden = indexPath.row == filter.subfilters.count - 1
            cell.accessibilityIdentifier = currentFilter.title

            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension RootFilterViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedFilter = filter.subfilters[indexPath.row]
        switch selectedFilter.kind {
        case .search, .inline:
            return
        default:
            delegate?.filterViewController(self, didSelectFilter: selectedFilter)
        }
    }
}

// MARK: - RootFilterCellDelegate

extension RootFilterViewController: RootFilterCellDelegate {
    func rootFilterCell(_ cell: RootFilterCell, didRemoveTagAt index: Int) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }

        let currentFilter = filter.subfilters[indexPath.row]
        let selectedSubfilters = selectionStore.selectedSubfilters(for: currentFilter)
        let filterToRemove = selectedSubfilters[index]

        selectionStore.removeValues(for: filterToRemove)
        rootDelegate?.rootFilterViewController(self, didRemoveFilter: filterToRemove)
        reloadCellsWithExclusiveFilters(for: currentFilter)
    }

    func rootFilterCellDidRemoveAllTags(_ cell: RootFilterCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }

        let currentFilter = filter.subfilters[indexPath.row]

        selectionStore.removeValues(for: currentFilter)
        rootDelegate?.rootFilterViewController(self, didRemoveFilter: currentFilter)
        reloadCellsWithExclusiveFilters(for: currentFilter)
    }

    private func reloadCellsWithExclusiveFilters(for filter: Filter) {
        let exclusiveFilterKeys = filter.mutuallyExclusiveFilterKeys

        let indexPathsToReload = self.filter.subfilters.enumerated().compactMap({ index, subfilter in
            return exclusiveFilterKeys.contains(subfilter.key) ? IndexPath(row: index, section: 0) : nil
        })

        tableView.reloadRows(at: indexPathsToReload, with: .none)
    }
}

// MARK: - CCInlineFilterViewDelegate

extension RootFilterViewController: InlineFilterViewDelegate {
    func inlineFilterView(_ inlineFilteView: InlineFilterView, didChange segment: Segment, at index: Int) {
        guard let inlineFilter = filter.subfilters.first(where: { $0.kind == .inline }) else { return }

        if let subfilter = inlineFilter.subfilter(at: index) {
            selectionStore.removeValues(for: subfilter)

            for index in segment.selectedItems {
                if let subfilter = subfilter.subfilter(at: index) {
                    selectionStore.setValue(from: subfilter)
                }
            }

            rootDelegate?.filterViewController(self, didSelectFilter: inlineFilter)
        }
    }

    func inlineFilterView(_ inlineFilterview: InlineFilterView, didTapExpandableSegment segment: Segment) {
        guard let verticals = verticals else { return }
        let verticalViewController = VerticalListViewController(verticals: verticals)
        verticalViewController.popoverTransitionDelegate.willDismissPopoverHandler = { _ in segment.selectedItems = [] }
        verticalViewController.popoverTransitionDelegate.sourceView = segment
        verticalViewController.delegate = self
        present(verticalViewController, animated: true, completion: nil)
    }
}

// MARK: - VerticalListViewControllerDelegate

extension RootFilterViewController: VerticalListViewControllerDelegate {
    func verticalListViewController(_ verticalViewController: VerticalListViewController, didSelectVerticalAtIndex index: Int) {
        freeTextFilterViewController?.searchBar.text = nil

        func dismissVerticalViewController(animated: Bool) {
            DispatchQueue.main.async {
                verticalViewController.dismiss(animated: animated)
            }
        }

        if verticals?.firstIndex(where: { $0.isCurrent }) != index {
            dismissVerticalViewController(animated: false)
            rootDelegate?.rootFilterViewController(self, didSelectVerticalAt: index)
        } else {
            dismissVerticalViewController(animated: true)
        }
    }
}

// MARK: - FreeTextFilterViewControllerDelegate

extension RootFilterViewController: FreeTextFilterViewControllerDelegate {
    func freeTextFilterViewController(_ viewController: FreeTextFilterViewController, didSelect value: String?, for filter: Filter) {
        rootDelegate?.filterViewController(self, didSelectFilter: filter)
    }

    func freeTextFilterViewControllerWillBeginEditing(_ viewController: FreeTextFilterViewController) {
        resetButton.isEnabled = false
        add(viewController)
    }

    func freeTextFilterViewControllerWillEndEditing(_ viewController: FreeTextFilterViewController) {
        resetButton.isEnabled = true
        viewController.remove()
        tableView.reloadData()
    }
}
