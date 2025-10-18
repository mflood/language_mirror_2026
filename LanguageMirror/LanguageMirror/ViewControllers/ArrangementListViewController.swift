//
//  ArrangementListViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//

//  ArrangementListViewController.swift
//  LanguageMirror
//  -------------------------------------------------------------
//  Lists all arrangements for a given AudioTrack.
//  -------------------------------------------------------------

import UIKit

final class ArrangementListViewController: UIViewController {

    // MARK: - Types
    private enum Section { case main }

    // MARK: - Dependencies
    private let track: AudioTrack
    private var arrangements: [PracticeSet] = []

    // MARK: - UI
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var dataSource: UITableViewDiffableDataSource<Section, PracticeSet>!

    // MARK: - Init
    init(track: AudioTrack) {
        self.track = track
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureTableView()
        configureDataSource()
        loadArrangements()
        applySnapshot()
    }

    // MARK: - View Setup
    private func configureView() {
        title = track.title
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
        dataSource = UITableViewDiffableDataSource<Section, Arrangement>(tableView: tableView) { tableView, _, arrangement in
            let cell = tableView.dequeueReusableCell(withIdentifier: "ArrangementCell")
                ?? UITableViewCell(style: .default, reuseIdentifier: "ArrangementCell")

            cell.textLabel?.text = arrangement.name
            cell.accessoryType   = .disclosureIndicator
            return cell
        }
    }

    // MARK: - Data Loading
    private func loadArrangements() {
        arrangements = DataManager.shared.arrangements(for: track.id)
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Arrangement>()
        snapshot.appendSections([.main])
        snapshot.appendItems(arrangements)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UITableViewDelegate
extension ArrangementListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let arrangement = dataSource.itemIdentifier(for: indexPath) else { return }
        let slices = DataManager.shared.slices(for: arrangement.id)

        let sliceVC = SliceListViewController(track: track,
                                              arrangement: arrangement,
                                              slices: slices)
        navigationController?.pushViewController(sliceVC, animated: true)
    }
}
