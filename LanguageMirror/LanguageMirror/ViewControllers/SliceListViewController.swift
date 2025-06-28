//
//  SliceListViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//
import UIKit

import UIKit

final class SliceListViewController: UIViewController {

    // MARK: - Types
    private enum Section { case main }

    // MARK: - Dependencies
    private let track: AudioTrack
    private let arrangement: Arrangement
    private let slices: [Slice]

    // MARK: - UI Elements
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var dataSource: UITableViewDiffableDataSource<Section, Slice>!

    // MARK: - Init
    init(track: AudioTrack, arrangement: Arrangement, slices: [Slice]) {
        self.track = track
        self.arrangement = arrangement
        self.slices = slices
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureTableView()
        configureDataSource()
        applyInitialSnapshot()
    }

    // MARK: - View Setup
    private func configureView() {
        title = arrangement.name
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
        dataSource = UITableViewDiffableDataSource<Section, Slice>(tableView: tableView) { tableView, _, slice in
            let cell = tableView.dequeueReusableCell(withIdentifier: "SliceCell") ??
                UITableViewCell(style: .subtitle, reuseIdentifier: "SliceCell")

            // Main title — time range
            cell.textLabel?.text = String(format: "%.2f – %.2f sec", slice.start, slice.end)

            // Subtitle — category
            if slice.category == .noise {
                cell.detailTextLabel?.text = "(Skip / Noise)"
                cell.textLabel?.textColor = .secondaryLabel
            } else {
                cell.detailTextLabel?.text = slice.transcript ?? "(learnable)"
                cell.textLabel?.textColor = .label
            }
            cell.selectionStyle = .none
            return cell
        }
    }

    private func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Slice>()
        snapshot.appendSections([.main])
        snapshot.appendItems(slices)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UITableViewDelegate (optional)
extension SliceListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let slice = dataSource.itemIdentifier(for: indexPath) else { return }
        tableView.deselectRow(at: indexPath, animated: true)

        if slice.category == .learnable {
            // TODO: preview playback if desired
            print("Preview slice", slice.start, slice.end)
        }
    }
}
