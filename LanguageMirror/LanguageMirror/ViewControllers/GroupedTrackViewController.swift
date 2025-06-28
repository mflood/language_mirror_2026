//
//  GroupedTrackViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//
//  LanguageMirror
//  -----------------------------------------------------------------
//  Shows all AudioTracks in a `Collection`, grouped by the
//  collection’s `groupOrder` (plus “Unclassified” + stray groups).
//  Uses UITableViewDiffableDataSource for easy updates.
//  -----------------------------------------------------------------

import UIKit

final class GroupedTrackViewController: UIViewController {

    // MARK: - Types
    /// Table sections are just the group names.
    private typealias Section = String

    // MARK: - Inputs
    private let collection: Collection

    // MARK: - UI
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var dataSource: UITableViewDiffableDataSource<Section, AudioTrack>!

    // MARK: - Init
    init(collection: Collection) {
        self.collection = collection
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureTableView()
        configureDataSource()
        applySnapshot()                       // populate the list
    }

    // MARK: - Configuration Helpers
    private func configureView() {
        title = collection.name
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
        dataSource = UITableViewDiffableDataSource<Section, AudioTrack>(tableView: tableView) { tableView, _, track in
            let cell = tableView.dequeueReusableCell(withIdentifier: "TrackCell")
                ?? UITableViewCell(style: .subtitle, reuseIdentifier: "TrackCell")

            cell.textLabel?.text = track.title
            cell.detailTextLabel?.text = track.sourceType.rawValue.capitalized
            cell.accessoryType = .disclosureIndicator
            return cell
        }
        dataSource.defaultRowAnimation = .fade
    }

    // MARK: - Snapshot Builder
    /// Builds section/row snapshot from `DataManager`.
    private func applySnapshot() {
        let sections = DataManager.shared.groupSections(for: collection)

        var snapshot = NSDiffableDataSourceSnapshot<Section, AudioTrack>()
        for (groupName, tracks) in sections {
            snapshot.appendSections([groupName])
            snapshot.appendItems(tracks)
        }
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}

// MARK: - UITableViewDelegate
extension GroupedTrackViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let track = dataSource.itemIdentifier(for: indexPath) else { return }
        let arrangementVC = ArrangementListViewController(track: track)
        navigationController?.pushViewController(arrangementVC, animated: true)
    }
}
