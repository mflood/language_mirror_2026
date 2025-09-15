//
//  PracticeViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

// path: Screens/PracticeViewController.swift
import UIKit

final class PracticeViewController: UITableViewController {

    private let settings: SettingsService
    private let library: LibraryService
    private let segments: SegmentService
    private let player: AudioPlayerService

    // Selected track (optional) + persisted last selection
    private var selectedTrack: Track? {
        didSet {
            if let t = selectedTrack {
                UserDefaults.standard.set(t.id, forKey: "practice.lastTrackId")
            }
            refreshDrillCount()
            reloadAll()
        }
    }

    private var drillCount: Int = 0

    // Controls (reuse behavior of Settings screen, but inline)
    private let repeatsStepper = UIStepper()
    private let gapSlider = UISlider()
    private let interGapSlider = UISlider()
    private let prerollSeg = UISegmentedControl(items: ["0ms", "100ms", "200ms", "300ms"])

    // Playback UI state
    private var isPlaying = false
    private var isPaused = false

    private enum Section: Int, CaseIterable { case target, controls, actions }
    private enum TargetRow: Int, CaseIterable { case track }
    private enum ControlRow: Int, CaseIterable { case repeats, gap, interGap, preroll }
    private enum ActionRow: Int, CaseIterable { case play }

    init(settings: SettingsService,
         libraryService: LibraryService,
         segmentService: SegmentService,
         audioPlayer: AudioPlayerService) {
        self.settings = settings
        self.library = libraryService
        self.segments = segmentService
        self.player = audioPlayer
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        configureControls()
        restoreLastTrackOrPickFirst()

        // Observe playback to toggle Pause/Stop buttons
        NotificationCenter.default.addObserver(self, selector: #selector(handlePlaybackStopped), name: .AudioPlayerDidStop, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePlaybackStarted), name: .AudioPlayerDidStart, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Setup

    private func configureControls() {
        // Repeats
        repeatsStepper.minimumValue = 1
        repeatsStepper.maximumValue = 20
        repeatsStepper.stepValue = 1
        repeatsStepper.value = Double(settings.globalRepeats)
        repeatsStepper.addTarget(self, action: #selector(repeatsChanged), for: .valueChanged)

        // Gap
        gapSlider.minimumValue = 0.0
        gapSlider.maximumValue = 2.0
        gapSlider.value = Float(settings.gapSeconds)
        gapSlider.addTarget(self, action: #selector(gapChanged), for: .valueChanged)

        // Inter-segment gap
        interGapSlider.minimumValue = 0.0
        interGapSlider.maximumValue = 2.0
        interGapSlider.value = Float(settings.interSegmentGapSeconds)
        interGapSlider.addTarget(self, action: #selector(interGapChanged), for: .valueChanged)

        // Preroll
        let values = [0, 100, 200, 300]
        let idx = values.firstIndex(of: max(0, min(settings.prerollMs, 300))) ?? 0
        prerollSeg.selectedSegmentIndex = idx
        prerollSeg.addTarget(self, action: #selector(prerollChanged), for: .valueChanged)
    }

    private func restoreLastTrackOrPickFirst() {
        if let lastId = UserDefaults.standard.string(forKey: "practice.lastTrackId"),
           let t = try? library.loadTrack(id: lastId) {
            selectedTrack = t
            return
        }
        // fallback: first track if exists
        if let first = library.listTracks(in: nil).first {
            selectedTrack = first
        }
    }

    private func refreshDrillCount() {
        guard let t = selectedTrack else { drillCount = 0; return }
        if let map = try? segments.loadMap(for: t.id) {
            drillCount = map.segments.filter { $0.kind == .drill }.count
        } else {
            drillCount = 0
        }
    }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .target: return "Target"
        case .controls: return "Quick Controls"
        case .actions: return "Run"
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .target: return TargetRow.allCases.count
        case .controls: return ControlRow.allCases.count
        case .actions: return ActionRow.allCases.count
        }
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var cfg = cell.defaultContentConfiguration()

        switch Section(rawValue: indexPath.section)! {
        case .target:
            cfg.text = "Track"
            if let t = selectedTrack {
                cfg.secondaryText = "\(t.title)  •  drills: \(drillCount)"
            } else {
                cfg.secondaryText = "Choose a track"
            }
            cell.accessoryType = .disclosureIndicator

        case .controls:
            switch ControlRow(rawValue: indexPath.row)! {
            case .repeats:
                cfg.text = "Repeats (N)"
                cfg.secondaryText = "\(settings.globalRepeats)x"
                cell.accessoryView = repeatsStepper
            case .gap:
                cfg.text = "Gap between repeats"
                cfg.secondaryText = String(format: "%.1fs", settings.gapSeconds)
                cell.accessoryView = gapSlider
            case .interGap:
                cfg.text = "Gap between segments"
                cfg.secondaryText = String(format: "%.1fs", settings.interSegmentGapSeconds)
                cell.accessoryView = interGapSlider
            case .preroll:
                cfg.text = "Preroll"
                cfg.secondaryText = "\(settings.prerollMs) ms"
                cell.accessoryView = prerollSeg
            }
            cell.selectionStyle = .none

        case .actions:
            cfg.text = "Play Drills"
            if selectedTrack == nil {
                cfg.secondaryText = "Select a track above"
            } else if drillCount == 0 {
                cfg.secondaryText = "No drills defined in this track"
            } else {
                cfg.secondaryText = "N=\(settings.globalRepeats) • gap \(String(format: "%.1f", settings.gapSeconds))s • inter \(String(format: "%.1f", settings.interSegmentGapSeconds))s • preroll \(settings.prerollMs)ms"
            }
            cell.textLabel?.textColor = view.tintColor
            cell.accessoryType = .disclosureIndicator
        }

        cell.contentConfiguration = cfg
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Section(rawValue: indexPath.section)! {
        case .target:
            let picker = PracticeTrackPickerViewController(libraryService: library)
            picker.onPick = { [weak self] t in
                self?.selectedTrack = t
            }
            navigationController?.pushViewController(picker, animated: true)

        case .controls:
            break

        case .actions:
            guard let t = selectedTrack else {
                presentAlert("No Track", "Select a track first.")
                return
            }
            let map = (try? segments.loadMap(for: t.id)) ?? .empty
            let drills = map.segments.filter { $0.kind == .drill }
            guard !drills.isEmpty else {
                presentAlert("No Drills", "This track has no Drill segments.")
                return
            }
            do {
                try player.play(track: t,
                                segments: drills,
                                globalRepeats: settings.globalRepeats,
                                gapSeconds: settings.gapSeconds,
                                interSegmentGapSeconds: settings.interSegmentGapSeconds,
                                prerollMs: settings.prerollMs)
                isPlaying = true
                isPaused = false
                updatePlaybackButtons()
            } catch {
                presentAlert("Playback Error", error.localizedDescription)
            }
        }
    }

    // MARK: - Control callbacks (persist to Settings)

    @objc private func repeatsChanged() {
        settings.globalRepeats = Int(repeatsStepper.value)
        reload(.controls)
    }
    @objc private func gapChanged() {
        let stepped = Double(round(gapSlider.value * 10) / 10)
        gapSlider.value = Float(stepped)
        settings.gapSeconds = Double(gapSlider.value)
        reload(.controls)
    }
    @objc private func interGapChanged() {
        let stepped = Double(round(interGapSlider.value * 10) / 10)
        interGapSlider.value = Float(stepped)
        settings.interSegmentGapSeconds = Double(interGapSlider.value)
        reload(.controls)
    }
    @objc private func prerollChanged() {
        let values = [0,100,200,300]
        let ms = values[prerollSeg.selectedSegmentIndex]
        settings.prerollMs = ms
        reload(.controls)
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
            player.resume()
            isPaused = false
            isPlaying = true
        } else {
            player.pause()
            isPaused = true
            isPlaying = false
        }
        updatePlaybackButtons()
    }

    @objc private func stopTapped() {
        player.stop()
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

    private func reloadAll() { tableView.reloadData() }

    private func reload(_ section: Section) {
        tableView.reloadSections(IndexSet(integer: section.rawValue), with: .none)
    }

    private func presentAlert(_ title: String, _ message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}
