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

    private func configureTable() { /* same pattern as above */ }

    private func configureDataSource() { /* similar */ }

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
