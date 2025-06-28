//
//  ArrangementListViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//

import UIKit

final class ArrangementListViewController: UIViewController {
    private enum Section { case main }

    private let track: AudioTrack
    private var arrangements: [Arrangement] = []
    private var tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var dataSource: UITableViewDiffableDataSource<Section, Arrangement>!

    init(track: AudioTrack) {
        self.track = track
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = track.title
        view.backgroundColor = .systemBackground
        configureTable()
        configureDataSource()
        loadMockArrangements()
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
        
        dataSource = UITableViewDiffableDataSource<Section, Arrangement>(tableView: tableView) { tableView, indexPath, arrangement in
            let cell = tableView.dequeueReusableCell(withIdentifier: "ArrCell") ?? UITableViewCell(style: .default, reuseIdentifier: "ArrCell")
            cell.textLabel?.text = arrangement.name
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }

    
    private func loadMockArrangements() {
        arrangements = [
            Arrangement(id: UUID(), name: "Sentence-Level"),
            Arrangement(id: UUID(), name: "Word-Level"),
            Arrangement(id: UUID(), name: "Full Track")
        ]
        var snap = NSDiffableDataSourceSnapshot<Section, Arrangement>()
        snap.appendSections([.main])
        snap.appendItems(arrangements)
        dataSource.apply(snap, animatingDifferences: true)
    }
}

extension ArrangementListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // TODO: push StudyPlayerVC here
    }
}
