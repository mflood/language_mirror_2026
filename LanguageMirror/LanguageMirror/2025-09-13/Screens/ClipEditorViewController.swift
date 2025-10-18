//
//  ClipEditorViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//

// path: Screens/ClipEditorViewController.swift
import UIKit

/// Dedicated editor for a track's clips.
/// - List clips
/// - Add / Edit / Delete / Reorder
/// - Quick cycle kind via swipe
final class ClipEditorViewController: UITableViewController {

    private let track: Track
    private let clipService: ClipService
    private let audioPlayer: AudioPlayerService
    private let settings: SettingsService

    private var map: PracticeSet!
    
    
    /// Called when the map changes so caller can refresh its UI.
    var onMapChanged: ((PracticeSet) -> Void)?

    init(track: Track, clipService: ClipService,
         audioPlayer: AudioPlayerService,
         settings: SettingsService
    ) {
        self.track = track
        self.map = track.practiceSets[0] // usually only one map
        self.clipService = clipService
        self.audioPlayer = audioPlayer
        self.settings = settings
        super.init(style: .insetGrouped)
        self.title = "Edit Clips"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addClipTapped)),
            UIBarButtonItem(title: "Reorder", style: .plain, target: self, action: #selector(toggleReorder))
        ]
        load()
    }

    private func load() {
        do {
            map = try clipService.loadMap(for: track.id)
            tableView.reloadData()
        } catch {
            // map = .empty
            tableView.reloadData()
            presentAlert(title: "Could not load clips", message: error.localizedDescription)
        }
    }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Clips for \(track.title)"
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(map.clips.count, 1)
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()

        if map.clips.isEmpty {
            config.text = "No clips yet"
            config.secondaryText = "Tap + to add your first clip"
            cell.selectionStyle = .none
            cell.accessoryType = .none
        } else {
            let clip = map.clips[indexPath.row]
            let title = clip.title?.isEmpty == false ? clip.title! : "(Untitled)"
            config.text = "[\(fmt(clip.startMs)) – \(fmt(clip.endMs))] \(title)"
            let repeats = clip.repeats.map { " • repeats: \($0)" } ?? ""
            config.secondaryText = "\(clip.kind.rawValue)\(repeats)"
            cell.selectionStyle = .default
            cell.accessoryType = .disclosureIndicator
        }

        cell.contentConfiguration = config
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !map.clips.isEmpty else { return }
        let clip = map.clips[indexPath.row]
        let editor = ClipWaveformEditorViewController(
            track: track,
            clip: clip,
            clipService: clipService,
            audioPlayer: audioPlayer,
            settings: settings
        )
        editor.onSaved = { [weak self] newMap in
            self?.map = newMap
            self?.tableView.reloadData()
            self?.onMapChanged?(newMap)
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    // Swipe actions
    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        guard !map.clips.isEmpty else { return nil }
        let clip = map.clips[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _,_,done in
            guard let self else { return }
            do {
                self.map = try self.clipService.delete(clipId: clip.id, from: self.track.id)
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
                if self.map.clips.isEmpty { self.tableView.reloadData() }
                self.onMapChanged?(self.map)
            } catch {
                self.presentAlert(title: "Delete failed", message: error.localizedDescription)
            }
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }

    override func tableView(_ tableView: UITableView,
                            leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        guard !map.clips.isEmpty else { return nil }
        let clip = map.clips[indexPath.row]
        let cycle = UIContextualAction(style: .normal, title: "Kind") { [weak self] _,_,done in
            guard let self else { return }
            var next = clip
            next.kind = self.nextKind(after: clip.kind)
            do {
                self.map = try self.clipService.update(next, in: self.track.id)
                self.tableView.reloadRows(at: [indexPath], with: .automatic)
                self.onMapChanged?(self.map)
            } catch {
                self.presentAlert(title: "Update failed", message: error.localizedDescription)
            }
            done(true)
        }
        cycle.backgroundColor = .systemBlue
        return UISwipeActionsConfiguration(actions: [cycle])
    }

    // Reorder
    override func tableView(_ tableView: UITableView,
                            canMoveRowAt indexPath: IndexPath) -> Bool {
        !map.clips.isEmpty
    }

    override func tableView(_ tableView: UITableView,
                            moveRowAt sourceIndexPath: IndexPath,
                            to destinationIndexPath: IndexPath) {
        do {
            map = try clipService.moveClip(from: sourceIndexPath.row,
                                                 to: destinationIndexPath.row,
                                                 in: track.id)
            onMapChanged?(map)
        } catch {
            presentAlert(title: "Reorder failed", message: error.localizedDescription)
        }
    }

    // MARK: - Actions

    @objc private func toggleReorder() {
        tableView.setEditing(!tableView.isEditing, animated: true)
        navigationItem.rightBarButtonItems?.last?.title = tableView.isEditing ? "Done" : "Reorder"
    }

    // Replace addTapped() to open the waveform editor for a new clip:
    @objc private func addClipTapped() {
        let editor = ClipWaveformEditorViewController(track: track, clip: nil, clipService: clipService,
                                                         audioPlayer: audioPlayer,
                                                         settings: settings
        )
        editor.onSaved = { [weak self] newMap in
            self?.map = newMap
            self?.tableView.reloadData()
            self?.onMapChanged?(newMap)
        }
        navigationController?.pushViewController(editor, animated: true)        
    }

    private func nextKind(after k: ClipKind) -> ClipKind {
        switch k {
        case .drill: return .skip
        case .skip:  return .noise
        case .noise: return .drill
        }
    }

    private func fmt(_ ms: Int) -> String {
        let totalSeconds = Double(ms) / 1000.0
        let m = Int(totalSeconds / 60.0)
        let s = Int(totalSeconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func presentAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}

