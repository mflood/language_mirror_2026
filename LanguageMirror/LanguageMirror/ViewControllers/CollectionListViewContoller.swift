//
//  CollectionListViewContoller.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//
//  LanguageMirror
//  -----------------------------------------------------------------
//  Entry screen that lists all `Collection` objects loaded by
//  `DataManager`.  Tapping a row pushes `GroupedTrackViewController`.
//  • Uses `UITableViewDiffableDataSource` for concise updates.
//  • Keeps layout code and data‑source setup in small helpers.
//  -----------------------------------------------------------------

import UIKit

final class CollectionListViewController: UIViewController {

    // MARK: - Types
    private enum Section { case main }

    // MARK: - UI Elements
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var dataSource: UITableViewDiffableDataSource<Section, Collection>!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureTableView()
        configureDataSource()
        applyInitialSnapshot()
    }

    // MARK: - Configuration Helpers
    private func configureView() {
        title = "Collections"
        view.backgroundColor = .systemBackground
    }

    private func configureTableView() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        tableView.delegate = self
    }

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<Section, Collection>(tableView: tableView) { tableView, indexPath, collection in
            let cell = tableView.dequeueReusableCell(withIdentifier: "CollectionCell")
                ?? UITableViewCell(style: .subtitle, reuseIdentifier: "CollectionCell")

            // Title & subtitle
            cell.textLabel?.text = collection.name
            cell.detailTextLabel?.text = "Groups: \(collection.groupOrder.count)"
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }

    private func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Collection>()
        snapshot.appendSections([.main])
        snapshot.appendItems(DataManager.shared.collections, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UITableViewDelegate
extension CollectionListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let collection = dataSource.itemIdentifier(for: indexPath) else { return }
        let tracksVC = GroupedTrackViewController(collection: collection)
        navigationController?.pushViewController(tracksVC, animated: true)
    }
}
