//
//  TrackViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/14/25.
//

import UIKit

final class TrackDetailViewController: UITableViewController {

    private let track: Track

    // If you later need services (e.g., LibraryService), inject here:
    // private let libraryService: LibraryService

    init(track: Track) {
        self.track = track
        super.init(style: .insetGrouped)
        self.title = track.title
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Table model

    private enum Section: Int, CaseIterable {
        case overview
        case actions
        // case segments // (future)
    }

    private enum OverviewRow: CaseIterable {
        case filename
        case duration
        case language
    }

    private enum ActionRow: CaseIterable {
        case startRoutine
        case editSegments
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        buildHeader()
    }

    private func buildHeader() {
        // Nice large header with the track title (optional, can delete if you prefer nav title only)
        let headerLabel = UILabel()
        headerLabel.text = track.title
        headerLabel.font = .systemFont(ofSize: 28, weight: .bold)
        headerLabel.numberOfLines = 0

        let headerView = UIView()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(headerLabel)
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 24),
            headerLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            headerLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            headerLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8)
        ])

        tableView.tableHeaderView = headerView
        headerView.layoutIfNeeded()
        let size = headerView.systemLayoutSizeFitting(CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height))
        headerView.frame = CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height))
    }

    // MARK: - Table datasource

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .overview: return "Overview"
        case .actions:  return "Actions"
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .overview: return OverviewRow.allCases.count
        case .actions:  return ActionRow.allCases.count
        }
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()

        switch Section(rawValue: indexPath.section)! {
        case .overview:
            let row = OverviewRow.allCases[indexPath.row]
            switch row {
            case .filename:
                config.text = "File"
                config.secondaryText = track.filename
                cell.selectionStyle = .none
            case .duration:
                config.text = "Duration"
                if let ms = track.durationMs {
                    config.secondaryText = msToClock(ms)
                } else {
                    config.secondaryText = "Unknown"
                }
                cell.selectionStyle = .none
            case .language:
                config.text = "Language"
                config.secondaryText = trackLanguageDisplay()
                cell.selectionStyle = .none
            }

        case .actions:
            let row = ActionRow.allCases[indexPath.row]
            switch row {
            case .startRoutine:
                config.text = "Start Routine"
                config.secondaryText = "Play all Drill segments (stub)"
                cell.accessoryType = .disclosureIndicator
            case .editSegments:
                config.text = "Edit Segments"
                config.secondaryText = "Open Segment Editor (stub)"
                cell.accessoryType = .disclosureIndicator
            }
        }

        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard Section(rawValue: indexPath.section) == .actions else { return }
        let row = ActionRow.allCases[indexPath.row]
        switch row {
        case .startRoutine:
            let alert = UIAlertController(
                title: "Start Routine",
                message: "This will play all Drill segments N times each (placeholder).",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)

        case .editSegments:
            let alert = UIAlertController(
                title: "Segment Editor",
                message: "This would push the Segment Editor (placeholder).",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    // MARK: - Helpers

    private func msToClock(_ ms: Int) -> String {
        let totalSeconds = ms / 1000
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func trackLanguageDisplay() -> String {
        // Track has languageCode optional; show that or "—"
        if let code = track.languageCode, !code.isEmpty {
            return code
        }
        return "—"
    }
}
