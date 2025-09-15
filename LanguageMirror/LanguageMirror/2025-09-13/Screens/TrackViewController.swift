//
//  TrackViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/14/25.
//

import UIKit

final class TrackDetailViewController: UITableViewController {

    private let track: Track
    private let audioPlayer: AudioPlayerService   // <— inject

    init(track: Track, audioPlayer: AudioPlayerService) {
        self.track = track
        self.audioPlayer = audioPlayer
        super.init(style: .insetGrouped)
        self.title = track.title
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Table model

    private enum Section: Int, CaseIterable { case overview, actions }
    private enum OverviewRow: CaseIterable { case filename, duration, language }
    private enum ActionRow: CaseIterable { case startRoutine, editSegments }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        buildHeader()
    }

    private func buildHeader() {
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
        let size = headerView.systemLayoutSizeFitting(CGSize(width: tableView.bounds.width,
                                                             height: UIView.layoutFittingCompressedSize.height))
        headerView.frame = CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height))
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

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
            switch OverviewRow.allCases[indexPath.row] {
            case .filename:
                config.text = "File"
                config.secondaryText = track.filename
                cell.selectionStyle = .none
            case .duration:
                config.text = "Duration"
                config.secondaryText = track.durationMs.map(msToClock) ?? "Unknown"
                cell.selectionStyle = .none
            case .language:
                config.text = "Language"
                config.secondaryText = trackLanguageDisplay()
                cell.selectionStyle = .none
            }

        case .actions:
            switch ActionRow.allCases[indexPath.row] {
            case .startRoutine:
                config.text = "Start Routine"
                config.secondaryText = "Play this track once (stub)"
                cell.accessoryType = .disclosureIndicator
            case .editSegments:
                config.text = "Edit Segments"
                config.secondaryText = "Open Segment Editor (placeholder)"
                cell.accessoryType = .disclosureIndicator
            }
        }

        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .actions else { return }

        switch ActionRow.allCases[indexPath.row] {
        case .startRoutine:
            do {
                try audioPlayer.play(track: track)
            } catch {
                let alert = UIAlertController(title: "Playback Error",
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }

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
        if let code = track.languageCode?.trimmingCharacters(in: .whitespacesAndNewlines),
           !code.isEmpty { return code }
        return "—"
    }
}

