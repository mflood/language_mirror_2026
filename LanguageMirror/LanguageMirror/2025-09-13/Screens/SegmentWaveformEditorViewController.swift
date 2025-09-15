//
//  SegmentWaveformEditorViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//


// REPLACE the whole file with this updated version (adds UIScrollView, zoom slider, snap toggle).
import UIKit
import AVFoundation

/// Visual editor for a single Segment using a waveform placeholder with draggable handles.
/// If `segment` is nil, creates a new one on save.
final class SegmentWaveformEditorViewController: UIViewController {

    private let track: Track
    private let segmentService: SegmentService
    private var segment: Segment? // editing target (optional)
    private let audioPlayer: AudioPlayerService          // NEW
    private let settings: SettingsService                // NEW

    var onSaved: ((SegmentMap) -> Void)?   // caller can refresh its UI

    // UI
    private let scroll = UIScrollView()
    private let waveform = WaveformPlaceholderView()
    private var waveformWidthConstraint: NSLayoutConstraint?

    private let startLabel = UILabel()
    private let endLabel = UILabel()
    private let durationLabel = UILabel()

    private let kindSeg = UISegmentedControl(items: SegmentKind.allCases.map { $0.rawValue })
    private let detailsButton = UIButton(type: .system)

    // Zoom + Snap controls
    private let zoomLabel = UILabel()
    private let zoomSlider = UISlider()
    private let snapSwitch = UISwitch()
    private let snapLabel = UILabel()

    // NEW: Play selection
    private let playButton = UIButton(type: .system)     // NEW
    private let loopSeg = UISegmentedControl(items: ["1×", "N×"])
    
    
    // Cached details (title/repeats/lang)
    private var titleText: String?
    private var repeatsVal: Int?
    private var langCode: String?

    // State
    private var durationMs: Int = 60_000
    private var zoom: CGFloat = 1.0 { didSet { applyZoom() } }
    private var isPlaying = false                        // NEW
    private var isPaused  = false                        // NEW

    init(track: Track, segment: Segment?, segmentService: SegmentService,
         audioPlayer: AudioPlayerService,                // NEW
                  settings: SettingsService
    ) {
        self.track = track
        self.segment = segment
        self.audioPlayer = audioPlayer
                self.settings = settings
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
        
        // NEW: observe playback notifications to toggle nav buttons
        NotificationCenter.default.addObserver(self, selector: #selector(handlePlaybackStopped), name: .AudioPlayerDidStop, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePlaybackStarted), name: .AudioPlayerDidStart, object: nil)
 
    }

    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loopSeg.setTitle("N× (\(settings.globalRepeats))", forSegmentAt: 1)
    }
 

    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Keep content width in sync with visible width * zoom on rotation/size change
        applyZoom()
    }

    private func setupUI() {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = true
        scroll.alwaysBounceHorizontal = true

        waveform.translatesAutoresizingMaskIntoConstraints = false

        startLabel.translatesAutoresizingMaskIntoConstraints = false
        endLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        [startLabel, endLabel].forEach {
            $0.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        }
        durationLabel.font = .systemFont(ofSize: 13)
        durationLabel.textColor = .secondaryLabel

        detailsButton.setTitle("Details…", for: .normal)
        detailsButton.translatesAutoresizingMaskIntoConstraints = false
        detailsButton.addTarget(self, action: #selector(detailsTapped), for: .touchUpInside)

        kindSeg.translatesAutoresizingMaskIntoConstraints = false
        kindSeg.selectedSegmentIndex = SegmentKind.allCases.firstIndex(of: segment?.kind ?? .drill) ?? 0

        // Zoom + Snap
        zoomLabel.text = "Zoom 1.0×"
        zoomLabel.translatesAutoresizingMaskIntoConstraints = false
        zoomSlider.translatesAutoresizingMaskIntoConstraints = false
        zoomSlider.minimumValue = 1.0
        zoomSlider.maximumValue = 10.0
        zoomSlider.value = 1.0
        zoomSlider.addTarget(self, action: #selector(zoomChanged), for: .valueChanged)

        snapLabel.text = "Snap to zero-crossing"
        snapLabel.translatesAutoresizingMaskIntoConstraints = false
        snapSwitch.translatesAutoresizingMaskIntoConstraints = false
        snapSwitch.isOn = true
        snapSwitch.addTarget(self, action: #selector(snapToggled), for: .valueChanged)

        // NEW: Play button
        playButton.setTitle("▶︎ Play Selection", for: .normal)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.addTarget(self, action: #selector(playSelectionTapped), for: .touchUpInside)

        loopSeg.translatesAutoresizingMaskIntoConstraints = false
        loopSeg.selectedSegmentIndex = 0
        loopSeg.setContentHuggingPriority(.required, for: .horizontal)
        // Show N value from Settings
        loopSeg.setTitle("N× (\(settings.globalRepeats))", forSegmentAt: 1)

        view.addSubview(scroll)
        scroll.addSubview(waveform)
        
        [startLabel, endLabel, durationLabel, kindSeg, detailsButton, zoomLabel, zoomSlider, snapLabel, snapSwitch, playButton, loopSeg].forEach {
            view.addSubview($0)
        }

        // Layout
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: g.topAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -12),
            scroll.heightAnchor.constraint(equalToConstant: 200),

            waveform.topAnchor.constraint(equalTo: scroll.topAnchor),
            waveform.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            waveform.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            waveform.heightAnchor.constraint(equalTo: scroll.heightAnchor),

            // Width is dynamic (visible width * zoom)
            // We'll set an initial constraint now; update in applyZoom()
        ])
        waveformWidthConstraint = waveform.widthAnchor.constraint(equalToConstant: 600)
        waveformWidthConstraint?.isActive = true
        scroll.contentSize = CGSize(width: CGFloat(600), height: 200)

        NSLayoutConstraint.activate([
            startLabel.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 8),
            startLabel.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),

            endLabel.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 8),
            endLabel.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),

            durationLabel.topAnchor.constraint(equalTo: startLabel.bottomAnchor, constant: 4),
            durationLabel.leadingAnchor.constraint(equalTo: startLabel.leadingAnchor),

            kindSeg.topAnchor.constraint(equalTo: durationLabel.bottomAnchor, constant: 12),
            kindSeg.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            kindSeg.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),

            detailsButton.topAnchor.constraint(equalTo: kindSeg.bottomAnchor, constant: 8),
            detailsButton.leadingAnchor.constraint(equalTo: kindSeg.leadingAnchor),

            zoomLabel.topAnchor.constraint(equalTo: detailsButton.bottomAnchor, constant: 16),
            zoomLabel.leadingAnchor.constraint(equalTo: detailsButton.leadingAnchor),

            zoomSlider.centerYAnchor.constraint(equalTo: zoomLabel.centerYAnchor),
            zoomSlider.leadingAnchor.constraint(equalTo: zoomLabel.trailingAnchor, constant: 12),
            zoomSlider.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),

            snapLabel.topAnchor.constraint(equalTo: zoomLabel.bottomAnchor, constant: 12),
            snapLabel.leadingAnchor.constraint(equalTo: zoomLabel.leadingAnchor),

            snapSwitch.centerYAnchor.constraint(equalTo: snapLabel.centerYAnchor),
            snapSwitch.leadingAnchor.constraint(equalTo: snapLabel.trailingAnchor, constant: 12),
        
            // Place loopSeg under the Snap row
            loopSeg.topAnchor.constraint(equalTo: snapLabel.bottomAnchor, constant: 16),
            loopSeg.leadingAnchor.constraint(equalTo: snapLabel.leadingAnchor),

            // Move Play button below the loop toggle
            playButton.topAnchor.constraint(equalTo: loopSeg.bottomAnchor, constant: 12),
            playButton.leadingAnchor.constraint(equalTo: loopSeg.leadingAnchor),


        ])

        waveform.onSelectionChanged = { [weak self] s, e in
            self?.renderTimes(s: s, e: e)
        }
    }

    private func loadDurationAndConfigure() {
        if let ms = track.durationMs {
            configure(durationMs: ms)
            return
        }
        if let url = AudioLocator.resolveURL(for: track) {
            let asset = AVAsset(url: url)
            let seconds = CMTimeGetSeconds(asset.duration)
            let ms = Int((seconds.isFinite ? seconds : 60.0) * 1000.0)
            configure(durationMs: max(ms, 1000))
        } else {
            // Audio missing — still let the editor work
            configure(durationMs: 60_000)
        }
    }

    private func configure(durationMs: Int) {
        self.durationMs = durationMs
        waveform.durationMs = durationMs

        if let seg = segment {
            waveform.setSelection(start: seg.startMs, end: seg.endMs)
            titleText = seg.title
            repeatsVal = seg.repeats
            langCode = seg.languageCode
            kindSeg.selectedSegmentIndex = SegmentKind.allCases.firstIndex(of: seg.kind) ?? 0
        } else {
            // default selection: middle
            let mid = durationMs / 2
            let half = min(1500, durationMs / 4)
            waveform.setSelection(start: max(0, mid - half), end: min(durationMs, mid + half))
        }

        renderTimes(s: waveform.startMs, e: waveform.endMs)
        durationLabel.text = "Track duration: \(fmt(durationMs))"

        // Initial zoom fit
        zoom = 1.0
        zoomSlider.value = 1.0
        waveform.snapEnabled = snapSwitch.isOn
    }

    private func applyZoom() {
        // Make content width = visible width * zoom
        let visibleWidth = view.bounds.width - 24 // account for leading/trailing constraints
        let newWidth = max(visibleWidth, visibleWidth * zoom)
        waveformWidthConstraint?.constant = newWidth
        scroll.contentSize = CGSize(width: newWidth, height: 200)
        zoomLabel.text = String(format: "Zoom %.1f×", zoom)
        view.layoutIfNeeded()
    }

    private func renderTimes(s: Int, e: Int) {
        startLabel.text = "Start: \(fmt(s))"
        endLabel.text = "End: \(fmt(e))"
    }

    @objc private func zoomChanged() {
        // snap to 0.1x increments for stable label values
        let stepped = round(zoomSlider.value * 10) / 10
        zoomSlider.value = stepped
        zoom = CGFloat(stepped)
    }

    @objc private func snapToggled() {
        waveform.snapEnabled = snapSwitch.isOn
    }
    
    // MARK: - NEW: Play selection

     @objc private func playSelectionTapped() {
         audioPlayer.stop()

         let s = waveform.startMs
         let e = waveform.endMs
         guard e > s else {
             presentAlert("Invalid Range", "End must be greater than start.")
             return
         }

         // Determine repeats & gap from toggle
         let repeats = (loopSeg.selectedSegmentIndex == 1) ? max(1, settings.globalRepeats) : 1
         let gap = (repeats > 1) ? settings.gapSeconds : 0.0

         // Build a transient segment (let’s explicitly set repeats to the chosen value)
         let temp = Segment(
             id: UUID().uuidString,
             startMs: s,
             endMs: e,
             kind: .drill,
             title: nil,
             repeats: repeats,
             languageCode: nil
         )

         do {
             try audioPlayer.play(
                 track: track,
                 segments: [temp],
                 globalRepeats: repeats,            // aligns with temp.repeats
                 gapSeconds: gap,                   // gap between repeats when looping
                 interSegmentGapSeconds: 0,
                 prerollMs: settings.prerollMs
             )
             isPlaying = true
             isPaused = false
             updatePlaybackButtons()
         } catch {
             presentAlert("Playback Error", error.localizedDescription)
         }
     }

     // Playback UI (reuse the lightweight pattern used elsewhere)
     private func updatePlaybackButtons() {
         if isPlaying {
             let pauseTitle = isPaused ? "Resume" : "Pause"
             let pauseItem = UIBarButtonItem(title: pauseTitle, style: .plain, target: self, action: #selector(pauseResumeTapped))
             let stopItem  = UIBarButtonItem(title: "Stop", style: .plain, target: self, action: #selector(stopTapped))
             navigationItem.rightBarButtonItems = [stopItem, pauseItem, navigationItem.rightBarButtonItem].compactMap { $0 }
         } else {
             // Keep Save button as the sole right item
             navigationItem.rightBarButtonItems = [navigationItem.rightBarButtonItem].compactMap { $0 }
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

     // ... existing saveTapped(), detailsTapped(), helpers ...

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
            if segment == nil { map = try segmentService.add(seg, to: track.id) }
            else { map = try segmentService.update(seg, in: track.id) }
            onSaved?(map)
            navigationController?.popViewController(animated: true)
        } catch {
            presentAlert("Save Failed", error.localizedDescription)
        }
    }

    @objc private func detailsTapped() {
        let alert = UIAlertController(title: "Details", message: "Optional metadata", preferredStyle: .alert)
        alert.addTextField { tf in tf.placeholder = "Title"; tf.text = self.titleText }
        alert.addTextField { tf in tf.placeholder = "Repeats (e.g., 3)"; tf.keyboardType = .numberPad; tf.text = self.repeatsVal.map(String.init) }
        alert.addTextField { tf in tf.placeholder = "Language (e.g., en-US)"; tf.autocapitalizationType = .none; tf.text = self.langCode }
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
