//
//  SliceListViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//
import UIKit

final class SliceListViewController: UIViewController {
    private enum Section { case main }
    private let track: AudioTrack
    private let arrangement: Arrangement
    private var slices: [Slice] = []

    private var tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var dataSource: UITableViewDiffableDataSource<Section, Slice>!

    init(track: AudioTrack, arrangement: Arrangement) {
        self.track = track; self.arrangement = arrangement; super.init(nibName:nil,bundle:nil)
    }
    required init?(coder:NSCoder){ fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad(); title = arrangement.name; view.backgroundColor = .systemBackground
        configureTable(); configureDataSource(); loadSlices()
    }

    private func configureTable() {
        view.addSubview(tableView); tableView.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo:view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo:view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo:view.bottomAnchor)
        ])
    }
    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<Section, Slice>(tableView: tableView) { tv, _, slice in
            let cell = tv.dequeueReusableCell(withIdentifier:"SliceCell") ?? UITableViewCell(style:.subtitle, reuseIdentifier:"SliceCell")
            let idx = tv.indexPath(for: cell)?.row ?? 0
            cell.textLabel?.text = "Slice \(idx + 1): " + (slice.transcript ?? "<noise>")
            let time = String(format: "%.2f–%.2f s", slice.start, slice.end)
            cell.detailTextLabel?.text = time
            cell.selectionStyle = .none
            if slice.category == .noise { cell.textLabel?.textColor = .secondaryLabel }
            return cell
        }
    }
    private func loadSlices() {
        slices = DataManager.shared.mockSlices()
        var snap = NSDiffableDataSourceSnapshot<Section, Slice>()
        snap.appendSections([.main]); snap.appendItems(slices)
        dataSource.apply(snap, animatingDifferences: true)
    }
}
