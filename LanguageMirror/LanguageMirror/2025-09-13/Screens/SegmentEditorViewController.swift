//
//  SegmentEditorViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//

// path: Screens/SegmentEditorViewController.swift
import UIKit

/// Dedicated editor for a track's segments.
/// - List segments
/// - Add / Edit / Delete / Reorder
/// - Quick cycle kind via swipe
final class SegmentEditorViewController: UITableViewController {

    private let track: Track
    private let segmentService: SegmentService
    private let audioPlayer: AudioPlayerService           // NEW
    private let settings: SettingsService                 // NEW
    
    private var map: SegmentMap = .empty

    /// Called when the map changes so caller can refresh its UI.
    var onMapChanged: ((SegmentMap) -> Void)?

    init(track: Track, segmentService: SegmentService,
         audioPlayer: AudioPlayerService,                 // NEW
         settings: SettingsService
    ) {
        self.track = track
        self.segmentService = segmentService
        self.audioPlayer = audioPlayer                       // NEW
        self.settings = settings                             // NEW
        super.init(style: .insetGrouped)
        self.title = "Edit Segments"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addSegmentTapped)),
            UIBarButtonItem(title: "Reorder", style: .plain, target: self, action: #selector(toggleReorder))
        ]
        load()
    }

    private func load() {
        do {
            map = try segmentService.loadMap(for: track.id)
            tableView.reloadData()
        } catch {
            map = .empty
            tableView.reloadData()
            presentAlert(title: "Could not load segments", message: error.localizedDescription)
        }
    }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Segments for \(track.title)"
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(map.segments.count, 1)
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()

        if map.segments.isEmpty {
            config.text = "No segments yet"
            config.secondaryText = "Tap + to add your first segment"
            cell.selectionStyle = .none
            cell.accessoryType = .none
        } else {
            let seg = map.segments[indexPath.row]
            let title = seg.title?.isEmpty == false ? seg.title! : "(Untitled)"
            config.text = "[\(fmt(seg.startMs)) – \(fmt(seg.endMs))] \(title)"
            let repeats = seg.repeats.map { " • repeats: \($0)" } ?? ""
            config.secondaryText = "\(seg.kind.rawValue)\(repeats)"
            cell.selectionStyle = .default
            cell.accessoryType = .disclosureIndicator
        }

        cell.contentConfiguration = config
        return cell
    }

    /*
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !map.segments.isEmpty else { return }
        let seg = map.segments[indexPath.row]
        presentEditForm(for: seg)
    }
     */
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !map.segments.isEmpty else { return }
        let seg = map.segments[indexPath.row]
        let editor = SegmentWaveformEditorViewController(track: track, segment: seg, segmentService: segmentService,
                                                         audioPlayer: audioPlayer,                      // NEW
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
        guard !map.segments.isEmpty else { return nil }
        let seg = map.segments[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _,_,done in
            guard let self else { return }
            do {
                self.map = try self.segmentService.delete(segmentId: seg.id, from: self.track.id)
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
                if self.map.segments.isEmpty { self.tableView.reloadData() }
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
        guard !map.segments.isEmpty else { return nil }
        let seg = map.segments[indexPath.row]
        let cycle = UIContextualAction(style: .normal, title: "Kind") { [weak self] _,_,done in
            guard let self else { return }
            var next = seg
            next.kind = self.nextKind(after: seg.kind)
            do {
                self.map = try self.segmentService.update(next, in: self.track.id)
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
        !map.segments.isEmpty
    }

    override func tableView(_ tableView: UITableView,
                            moveRowAt sourceIndexPath: IndexPath,
                            to destinationIndexPath: IndexPath) {
        do {
            map = try segmentService.moveSegment(from: sourceIndexPath.row,
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

    // Replace addTapped() to open the waveform editor for a new segment:
    @objc private func addSegmentTapped() {
        let editor = SegmentWaveformEditorViewController(track: track, segment: nil, segmentService: segmentService,
                                                         audioPlayer: audioPlayer,                      // NEW
                                                         settings: settings                             // NEW
        )
        editor.onSaved = { [weak self] newMap in
            self?.map = newMap
            self?.tableView.reloadData()
            self?.onMapChanged?(newMap)
        }
        navigationController?.pushViewController(editor, animated: true)        
    }
    
    @objc private func addTapped() {
        presentEditForm(for: nil)
    }

    private func presentEditForm(for segment: Segment?) {
        let editing = segment != nil
        let title = editing ? "Edit Segment" : "Add Segment"
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)

        alert.addTextField { tf in
            tf.placeholder = "Start (ms)"
            tf.keyboardType = .numberPad
            tf.text = segment.map { String($0.startMs) } ?? ""
        }
        alert.addTextField { tf in
            tf.placeholder = "End (ms)"
            tf.keyboardType = .numberPad
            tf.text = segment.map { String($0.endMs) } ?? ""
        }
        alert.addTextField { tf in
            tf.placeholder = "Title (optional)"
            tf.text = segment?.title ?? ""
        }
        alert.addTextField { tf in
            tf.placeholder = "Repeats (optional, e.g., 3)"
            tf.keyboardType = .numberPad
            tf.text = segment?.repeats.map(String.init) ?? ""
        }
        alert.addTextField { tf in
            tf.placeholder = "Language (optional, e.g., en-US)"
            tf.autocapitalizationType = .none
            tf.text = segment?.languageCode ?? ""
        }

        // Kind picker via actions
        var chosenKind = segment?.kind ?? .drill
        let makeKindAction: (SegmentKind) -> UIAlertAction = { kind in
            UIAlertAction(title: (chosenKind == kind ? "✓ " : "") + kind.rawValue,
                          style: .default) { _ in chosenKind = kind; self.present(alert, animated: true) }
        }
        // We'll add a compact cycle button too
        alert.addAction(UIAlertAction(title: "Cycle Kind (\(chosenKind.rawValue))", style: .default) { _ in
            chosenKind = self.nextKind(after: chosenKind)
            self.present(alert, animated: true)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: editing ? "Save" : "Add", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            let start = Int(alert.textFields?[0].text ?? "")
            let end   = Int(alert.textFields?[1].text ?? "")
            let title = alert.textFields?[2].text?.trimmingCharacters(in: .whitespacesAndNewlines)
            let reps  = Int(alert.textFields?[3].text ?? "")
            let lang  = alert.textFields?[4].text?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let s = start, let e = end, s >= 0, e > s else {
                self.presentAlert(title: "Invalid input", message: "Enter non-negative start, and end > start.")
                return
            }

            var newSeg = segment ?? Segment(id: UUID().uuidString, startMs: s, endMs: e, kind: chosenKind, title: title, repeats: reps, languageCode: lang)
            newSeg.startMs = s
            newSeg.endMs = e
            newSeg.kind = chosenKind
            newSeg.title = (title?.isEmpty == false) ? title : nil
            newSeg.repeats = reps
            newSeg.languageCode = (lang?.isEmpty == false) ? lang : nil

            do {
                if editing {
                    self.map = try self.segmentService.update(newSeg, in: self.track.id)
                } else {
                    self.map = try self.segmentService.add(newSeg, to: self.track.id)
                }
                self.tableView.reloadData()
                self.onMapChanged?(self.map)
            } catch {
                self.presentAlert(title: "Save failed", message: error.localizedDescription)
            }
        }))

        present(alert, animated: true)
    }

    // MARK: - Helpers

    private func nextKind(after k: SegmentKind) -> SegmentKind {
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
