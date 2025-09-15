//
//  SegmentWaveformEditorViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//

// path: Screens/SegmentWaveformEditorViewController.swift
import UIKit
import AVFoundation

/// Visual editor for a single Segment using a waveform placeholder with draggable handles.
/// If `segment` is nil, creates a new one on save.
final class SegmentWaveformEditorViewController: UIViewController {

    private let track: Track
    private let segmentService: SegmentService
    private var segment: Segment? // editing target (optional)

    var onSaved: ((SegmentMap) -> Void)?   // caller can refresh its UI

    // UI
    private let waveform = WaveformPlaceholderView()
    private let startLabel = UILabel()
    private let endLabel = UILabel()
    private let durationLabel = UILabel()
    private let kindSeg = UISegmentedControl(items: SegmentKind.allCases.map { $0.rawValue })
    private let detailsButton = UIButton(type: .system)

    // Cached details (title/repeats/lang)
    private var titleText: String?
    private var repeatsVal: Int?
    private var langCode: String?

    init(track: Track, segment: Segment?, segmentService: SegmentService) {
        self.track = track
        self.segment = segment
        self.segmentService = segmentService
        super.init(nibName: nil, bundle: nil)
        self.title = segment == nil ? "New Segment" : "Edit Segment"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        loadDurationAndConfigure()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveTapped))
    }

    private func setupUI() {
        waveform.translatesAutoresizingMaskIntoConstraints = false
        startLabel.translatesAutoresizingMaskIntoConstraints = false
        endLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        kindSeg.translatesAutoresizingMaskIntoConstraints = false
        detailsButton.translatesAutoresizingMaskIntoConstraints = false

        startLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        endLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        durationLabel.font = .systemFont(ofSize: 13)
        durationLabel.textColor = .secondaryLabel

        detailsButton.setTitle("Details…", for: .normal)
        detailsButton.addTarget(self, action: #selector(detailsTapped), for: .touchUpInside)

        view.addSubview(waveform)
        view.addSubview(startLabel)
        view.addSubview(endLabel)
        view.addSubview(durationLabel)
        view.addSubview(kindSeg)
        view.addSubview(detailsButton)

        NSLayoutConstraint.activate([
            waveform.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            waveform.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            waveform.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            waveform.heightAnchor.constraint(equalToConstant: 180),

            startLabel.topAnchor.constraint(equalTo: waveform.bottomAnchor, constant: 8),
            startLabel.leadingAnchor.constraint(equalTo: waveform.leadingAnchor),

            endLabel.topAnchor.constraint(equalTo: waveform.bottomAnchor, constant: 8),
            endLabel.trailingAnchor.constraint(equalTo: waveform.trailingAnchor),

            durationLabel.topAnchor.constraint(equalTo: startLabel.bottomAnchor, constant: 4),
            durationLabel.leadingAnchor.constraint(equalTo: startLabel.leadingAnchor),

            kindSeg.topAnchor.constraint(equalTo: durationLabel.bottomAnchor, constant: 16),
            kindSeg.leadingAnchor.constraint(equalTo: waveform.leadingAnchor),
            kindSeg.trailingAnchor.constraint(equalTo: waveform.trailingAnchor),

            detailsButton.topAnchor.constraint(equalTo: kindSeg.bottomAnchor, constant: 12),
            detailsButton.leadingAnchor.constraint(equalTo: kindSeg.leadingAnchor)
        ])

        kindSeg.selectedSegmentIndex = SegmentKind.allCases.firstIndex(of: segment?.kind ?? .drill) ?? 0

        waveform.onSelectionChanged = { [weak self] s, e in
            self?.renderTimes(s: s, e: e)
        }
    }

    private func loadDurationAndConfigure() {
        // Determine duration: prefer Track.durationMs else read via AVAsset
        if let ms = track.durationMs {
            configure(durationMs: ms)
            return
        }
        guard let url = AudioLocator.resolveURL(for: track) else {
            presentAlert("Audio Missing", "Could not locate audio file \(track.filename).")
            // pick a default duration to allow UI anyway
            configure(durationMs: 60_000)
            return
        }
        let asset = AVAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        let ms = Int((seconds.isFinite ? seconds : 60.0) * 1000.0)
        configure(durationMs: max(ms, 1000))
    }

    private func configure(durationMs: Int) {
        waveform.durationMs = durationMs

        if let seg = segment {
            waveform.setSelection(start: seg.startMs, end: seg.endMs)
            self.titleText = seg.title
            self.repeatsVal = seg.repeats
            self.langCode = seg.languageCode
        } else {
            // default selection: middle 3 seconds
            let mid = durationMs / 2
            let half = min(1500, durationMs / 4)
            waveform.setSelection(start: max(0, mid - half), end: min(durationMs, mid + half))
        }

        renderTimes(s: waveform.startMs, e: waveform.endMs)
        durationLabel.text = "Track duration: \(fmt(waveform.durationMs))"
    }

    private func renderTimes(s: Int, e: Int) {
        startLabel.text = "Start: \(fmt(s))"
        endLabel.text = "End: \(fmt(e))"
    }

    @objc private func saveTapped() {
        let s = waveform.startMs
        let e = waveform.endMs
        guard e > s else {
            presentAlert("Invalid Range", "End must be greater than start.")
            return
        }
        let chosenKind = SegmentKind.allCases[kindSeg.selectedSegmentIndex]
        var seg = segment ?? Segment(id: UUID().uuidString, startMs: s, endMs: e, kind: chosenKind, title: nil, repeats: nil, languageCode: nil)
        seg.startMs = s
        seg.endMs = e
        seg.kind = chosenKind
        seg.title = (titleText?.isEmpty == false) ? titleText : nil
        seg.repeats = repeatsVal
        seg.languageCode = (langCode?.isEmpty == false) ? langCode : nil

        do {
            let map: SegmentMap
            if segment == nil {
                map = try segmentService.add(seg, to: track.id)
            } else {
                map = try segmentService.update(seg, in: track.id)
            }
            onSaved?(map)
            navigationController?.popViewController(animated: true)
        } catch {
            presentAlert("Save Failed", error.localizedDescription)
        }
    }

    @objc private func detailsTapped() {
        let alert = UIAlertController(title: "Details", message: "Optional metadata", preferredStyle: .alert)
        alert.addTextField { tf in tf.placeholder = "Title"; tf.text = self.titleText }
        alert.addTextField { tf in
            tf.placeholder = "Repeats (e.g., 3)"; tf.keyboardType = .numberPad
            tf.text = self.repeatsVal.map(String.init)
        }
        alert.addTextField { tf in
            tf.placeholder = "Language (e.g., en-US)"; tf.autocapitalizationType = .none
            tf.text = self.langCode
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            let t = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines)
            let r = Int(alert.textFields?[1].text ?? "")
            let l = alert.textFields?[2].text?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.titleText = (t?.isEmpty == false) ? t : nil
            self.repeatsVal = r
            self.langCode = (l?.isEmpty == false) ? l : nil
        }))
        present(alert, animated: true)
    }

    // MARK: - Helpers

    private func fmt(_ ms: Int) -> String {
        let sec = Double(ms) / 1000.0
        let m = Int(sec / 60.0)
        let s = Int(sec) % 60
        let cs = Int((sec - floor(sec)) * 100)
        return String(format: "%d:%02d.%02d", m, s, cs)
    }

    private func presentAlert(_ title: String, _ message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}
