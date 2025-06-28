//
//  TrackViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//

import UIKit

final class TrackViewController: UIViewController {
    private enum Section { case main }

    private var tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var dataSource: UITableViewDiffableDataSource<Section, AudioTrack>!
    private var tracks: [AudioTrack] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tracks"
        view.backgroundColor = .systemBackground
        configureTable()
        configureDataSource()
        // tracks = DataManager.shared.loadTracks()
        applySnapshot()
    }

    private func configureTable() {
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
        dataSource = UITableViewDiffableDataSource<Section, AudioTrack>(
            tableView: tableView) { tableView, indexPath, track in
            let cell = tableView.dequeueReusableCell(withIdentifier: "TrackCell")
                        ?? UITableViewCell(style: .subtitle, reuseIdentifier: "TrackCell")
            cell.textLabel?.text = track.title
            cell.detailTextLabel?.text = track.sourceType.rawValue.capitalized
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }

    private func applySnapshot() {
        var snap = NSDiffableDataSourceSnapshot<Section, AudioTrack>()
        snap.appendSections([.main])
        snap.appendItems(tracks)
        dataSource.apply(snap, animatingDifferences: true)
    }
}

extension TrackViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let track = dataSource.itemIdentifier(for: indexPath) else { return }
        let vc = ArrangementListViewController(track: track)
        navigationController?.pushViewController(vc, animated: true)
    }
}
