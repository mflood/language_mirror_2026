//
//  TrackViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/14/25.
//
// path: Screens/TrackDetailViewController.swift
// Replace the whole file with the updated version below (only differences: Start Routine calls repeats+gap,
// plus Pause/Resume/Stop nav buttons and notification handling).
import UIKit

final class TrackDetailViewController: UITableViewController {

    private let track: Track
    private let audioPlayer: AudioPlayerService
    private let segmentService: SegmentService

    private var segmentMap: SegmentMap = .empty

    // Playback config (temporary defaults; later from Settings)
    private let defaultRepeats = 3
    private let defaultGap: TimeInterval = 0.5
    private let defaultInterSegmentGap: TimeInterval = 0.5  // NEW

    // Local UI state
    private var isPlaying: Bool = false
    private var isPaused: Bool = false

    init(track: Track, audioPlayer: AudioPlayerService, segmentService: SegmentService) {
        self.track = track
        self.audioPlayer = audioPlayer
        self.segmentService = segmentService
        super.init(style: .insetGrouped)
        self.title = track.title
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private enum Section: Int, CaseIterable { case overview, actions, segments }
    private enum OverviewRow: CaseIterable { case filename, duration, language }
    private enum ActionRow: CaseIterable { case startRoutine, editSegments }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        buildHeader()
        loadSegments()

        // Observe playback end to reset buttons
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handlePlaybackStopped),
                                               name: .AudioPlayerDidStop,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handlePlaybackStarted),
                                               name: .AudioPlayerDidStart,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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

    private func loadSegments() {
        do {
            segmentMap = try segmentService.loadMap(for: track.id)
            tableView.reloadData()
        } catch {
            segmentMap = .empty
            tableView.reloadData()
            presentError("Could not load segments", error: error)
        }
    }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .overview: return "Overview"
        case .actions:  return "Actions"
        case .segments: return "Segments"
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .overview: return OverviewRow.allCases.count
        case .actions:  return ActionRow.allCases.count
        case .segments: return max(segmentMap.segments.count, 1)
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
                let drillCount = segmentMap.segments.filter { $0.kind == .drill }.count
                config.text = "Start Routine"
                
                if drillCount > 0 {
                    config.secondaryText = "Play \(drillCount) drills • \(defaultRepeats)x • gap \(defaultGap)s"
                } else {
                    config.secondaryText = "No drills defined (add segments)"
                }
                
                cell.accessoryType = .disclosureIndicator
            case .editSegments:
                config.text = "Edit Segments"
                config.secondaryText = "Open Segment Editor"
                cell.accessoryType = .disclosureIndicator
            }

        case .segments:
            if segmentMap.segments.isEmpty {
                config.text = "No segments yet"
                config.secondaryText = "Tap Edit Segments to add"
                cell.selectionStyle = .none
                cell.accessoryType = .none
            } else {
                let seg = segmentMap.segments[indexPath.row]
                let title = seg.title?.isEmpty == false ? seg.title! : "(Untitled)"
                config.text = "[\(formatTime(seg.startMs)) – \(formatTime(seg.endMs))] \(title)"
                let repeats = seg.repeats.map { " • repeats: \($0)" } ?? ""
                config.secondaryText = "\(seg.kind.rawValue)\(repeats)"
                cell.selectionStyle = .none
                cell.accessoryType = .disclosureIndicator
            }
        }

        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .actions:
            switch ActionRow.allCases[indexPath.row] {
            case .startRoutine:
                let drills = segmentMap.segments.filter { $0.kind == .drill }
                    guard !drills.isEmpty else {
                        presentMessage("No Drills", "Add segments and mark some as Drill to practice.")
                        return
                    }
                
                do {
                    try audioPlayer.play(track: track,
                                         segments: drills,
                                         globalRepeats: defaultRepeats,
                                         gapSeconds: defaultGap,
                                         interSegmentGapSeconds: defaultInterSegmentGap)
                    isPlaying = true
                    isPaused = false
                    updatePlaybackButtons()
                } catch {
                    presentError("Playback Error", error: error)
                }
            case .editSegments:
                let editor = SegmentEditorViewController(track: track, segmentService: segmentService)
                editor.onMapChanged = { [weak self] newMap in
                    self?.segmentMap = newMap
                    if let section = Section.allCases.firstIndex(of: .segments) {
                        self?.tableView.reloadSections(IndexSet(integer: section), with: .automatic)
                    } else {
                        self?.tableView.reloadData()
                    }
                }
                navigationController?.pushViewController(editor, animated: true)
            }
        case .overview, .segments:
            break
        }
    }

    // MARK: - Playback UI

    private func updatePlaybackButtons() {
        if isPlaying {
            let pauseTitle = isPaused ? "Resume" : "Pause"
            let pauseItem = UIBarButtonItem(title: pauseTitle, style: .plain, target: self, action: #selector(pauseResumeTapped))
            let stopItem  = UIBarButtonItem(title: "Stop", style: .plain, target: self, action: #selector(stopTapped))
            navigationItem.rightBarButtonItems = [stopItem, pauseItem]
        } else {
            navigationItem.rightBarButtonItems = nil
        }
    }

    @objc private func pauseResumeTapped() {
        if isPaused {
            audioPlayer.resume()
            isPaused = false
            isPlaying = true
        } else {
            audioPlayer.pause()
            isPaused = true
            isPlaying = false
        }
        updatePlaybackButtons()
    }

    @objc private func stopTapped() {
        audioPlayer.stop()
        isPaused = false
        isPlaying = false
        updatePlaybackButtons()
    }

    @objc private func handlePlaybackStopped() {
        isPaused = false
        isPlaying = false
        updatePlaybackButtons()
    }

    @objc private func handlePlaybackStarted() {
        isPaused = false
        isPlaying = true
        updatePlaybackButtons()
    }

    // MARK: - Helpers

    private func msToClock(_ ms: Int) -> String {
        let totalSeconds = ms / 1000
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatTime(_ ms: Int) -> String {
        let totalSeconds = Double(ms) / 1000.0
        let m = Int(totalSeconds / 60.0)
        let s = Int(totalSeconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func trackLanguageDisplay() -> String {
        if let code = track.languageCode?.trimmingCharacters(in: .whitespacesAndNewlines),
           !code.isEmpty { return code }
        return "—"
    }

    private func presentError(_ title: String, error: Error) {
        presentMessage(title, error.localizedDescription)
    }

    private func presentMessage(_ title: String, _ message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}
