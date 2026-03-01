//
//  AudioRecorderViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/18/25.
//

// path: Screens/AudioRecorderViewController.swift
import UIKit
import AVFoundation
import AVFAudio

final class AudioRecorderViewController: UIViewController, AVAudioRecorderDelegate {

    // MARK: - Public Callbacks

    var onFinished: ((URL) -> Void)?
    var onCancelled: (() -> Void)?

    // MARK: - State Machine

    private enum RecorderState { case ready, recording, review }

    private var state: RecorderState = .ready {
        didSet { transitionState(from: oldValue, to: state) }
    }

    // MARK: - Recording

    private var recorder: AVAudioRecorder?
    private var recordedURL: URL?
    private var didEmitCallback = false
    private var recordingStartTime: Date?
    private var recordingTimer: Timer?
    private var amplitudeTimer: Timer?

    // MARK: - Playback (Review)

    private var player: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var isPlaying = false

    // MARK: - Haptics

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let successNotification = UINotificationFeedbackGenerator()

    // MARK: - Ready State UI

    private let recordButton = UIView()
    private let recordButtonIcon = UIImageView()
    private let glowRingView = UIView()
    private let hintLabel = UILabel()
    private let secondaryHintLabel = UILabel()

    // MARK: - Recording State UI

    private let timerLabel = UILabel()
    private let waveformView = ScrollingWaveformView()
    private let volumeMeterTrack = UIView()
    private let volumeMeterFill = UIView()
    private let stopButton = UIView()
    private let stopButtonIcon = UIImageView()
    private let recDot = UIView()
    private let recLabel = UILabel()

    // MARK: - Review State UI

    private let completeTitleLabel = UILabel()
    private let durationLabel = UILabel()
    private let playbackTimeLabel = UILabel()
    private let playPauseButton = UIView()
    private let playPauseIcon = UIImageView()
    private let reRecordButton = UIButton(type: .system)
    private let useRecordingButton = UIButton(type: .system)

    // MARK: - Constraint Groups

    private var readyConstraints: [NSLayoutConstraint] = []
    private var recordingConstraints: [NSLayoutConstraint] = []
    private var reviewConstraints: [NSLayoutConstraint] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        prepareHaptics()
        applyState(.ready, animated: false)
        scheduleSecondaryHint()
        startBreathingAnimation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Recompute timer if recording resumed from background
        if state == .recording, let start = recordingStartTime {
            updateTimerDisplay(from: start)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            if state == .recording {
                stopRecorderAndTimers()
            }
            if state == .review, !didEmitCallback {
                stopPlayback()
            }
        }
    }

    deinit {
        stopRecorderAndTimers()
        stopPlayback()
        // Clean up temp file if never used
        if !didEmitCallback, let url = recordedURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            waveformView.updateColors()
            recordButton.applyAdaptiveShadow(radius: 12, opacity: 0.2)
            stopButton.applyAdaptiveShadow(radius: 10, opacity: 0.2)
            playPauseButton.applyAdaptiveShadow(radius: 8, opacity: 0.15)
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = AppColors.calmBackground
        title = "Record"

        setupReadyComponents()
        setupRecordingComponents()
        setupReviewComponents()
        buildConstraints()
    }

    // MARK: Ready Components

    private func setupReadyComponents() {
        // Glow ring (behind record button)
        glowRingView.translatesAutoresizingMaskIntoConstraints = false
        glowRingView.backgroundColor = AppColors.accentGlow
        glowRingView.layer.cornerRadius = 104
        glowRingView.layer.cornerCurve = .continuous
        glowRingView.alpha = 0.3
        glowRingView.isUserInteractionEnabled = false
        view.addSubview(glowRingView)

        // Record button
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.backgroundColor = AppColors.primaryAccent
        recordButton.layer.cornerRadius = 80
        recordButton.layer.cornerCurve = .continuous
        recordButton.applyAdaptiveShadow(radius: 12, opacity: 0.2)
        recordButton.isAccessibilityElement = true
        recordButton.accessibilityLabel = "Start recording"
        recordButton.accessibilityTraits = .button
        recordButton.accessibilityHint = "Double tap to start recording"
        recordButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(recordButtonTapped)))
        view.addSubview(recordButton)

        // Mic icon
        recordButtonIcon.translatesAutoresizingMaskIntoConstraints = false
        recordButtonIcon.contentMode = .scaleAspectFit
        recordButtonIcon.tintColor = .white
        recordButtonIcon.image = UIImage(systemName: "mic.fill")
        recordButtonIcon.isAccessibilityElement = false
        recordButton.addSubview(recordButtonIcon)

        // Hint label
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.text = "Tap to start recording"
        hintLabel.font = .preferredFont(forTextStyle: .callout)
        hintLabel.textColor = AppColors.secondaryText
        hintLabel.textAlignment = .center
        hintLabel.adjustsFontForContentSizeCategory = true
        view.addSubview(hintLabel)

        // Secondary hint (delayed)
        secondaryHintLabel.translatesAutoresizingMaskIntoConstraints = false
        secondaryHintLabel.text = "Record yourself speaking or reading aloud"
        secondaryHintLabel.font = .preferredFont(forTextStyle: .footnote)
        secondaryHintLabel.textColor = AppColors.tertiaryText
        secondaryHintLabel.textAlignment = .center
        secondaryHintLabel.alpha = 0
        secondaryHintLabel.adjustsFontForContentSizeCategory = true
        view.addSubview(secondaryHintLabel)
    }

    // MARK: Recording Components

    private func setupRecordingComponents() {
        // REC dot
        recDot.translatesAutoresizingMaskIntoConstraints = false
        recDot.backgroundColor = .systemRed
        recDot.layer.cornerRadius = 5
        view.addSubview(recDot)

        // REC label
        recLabel.translatesAutoresizingMaskIntoConstraints = false
        recLabel.text = "REC"
        recLabel.font = .systemFont(ofSize: 13, weight: .bold)
        recLabel.textColor = .systemRed
        view.addSubview(recLabel)

        // Timer label
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 34, weight: .semibold)
        timerLabel.textColor = AppColors.primaryText
        timerLabel.textAlignment = .center
        timerLabel.text = "0:00"
        timerLabel.adjustsFontForContentSizeCategory = true
        timerLabel.accessibilityLabel = "Recording duration"
        timerLabel.accessibilityTraits = .updatesFrequently
        view.addSubview(timerLabel)

        // Waveform view
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(waveformView)

        // Volume meter track
        volumeMeterTrack.translatesAutoresizingMaskIntoConstraints = false
        volumeMeterTrack.backgroundColor = AppColors.tertiaryBackground
        volumeMeterTrack.layer.cornerRadius = 2
        view.addSubview(volumeMeterTrack)

        // Volume meter fill
        volumeMeterFill.translatesAutoresizingMaskIntoConstraints = false
        volumeMeterFill.backgroundColor = AppColors.primaryAccent
        volumeMeterFill.layer.cornerRadius = 2
        volumeMeterTrack.addSubview(volumeMeterFill)

        // Stop button
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.backgroundColor = .systemRed
        stopButton.layer.cornerRadius = 60
        stopButton.layer.cornerCurve = .continuous
        stopButton.applyAdaptiveShadow(radius: 10, opacity: 0.2)
        stopButton.isAccessibilityElement = true
        stopButton.accessibilityLabel = "Stop recording"
        stopButton.accessibilityTraits = .button
        stopButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(stopButtonTapped)))
        view.addSubview(stopButton)

        // Stop icon
        stopButtonIcon.translatesAutoresizingMaskIntoConstraints = false
        stopButtonIcon.contentMode = .scaleAspectFit
        stopButtonIcon.tintColor = .white
        stopButtonIcon.image = UIImage(systemName: "stop.fill")
        stopButtonIcon.isAccessibilityElement = false
        stopButton.addSubview(stopButtonIcon)
    }

    // MARK: Review Components

    private func setupReviewComponents() {
        // Complete title
        completeTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        completeTitleLabel.text = "Recording Complete"
        completeTitleLabel.font = .preferredFont(forTextStyle: .title2)
        completeTitleLabel.textColor = AppColors.primaryText
        completeTitleLabel.textAlignment = .center
        completeTitleLabel.adjustsFontForContentSizeCategory = true
        view.addSubview(completeTitleLabel)

        // Duration label
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.font = .preferredFont(forTextStyle: .subheadline)
        durationLabel.textColor = AppColors.secondaryText
        durationLabel.textAlignment = .center
        durationLabel.adjustsFontForContentSizeCategory = true
        view.addSubview(durationLabel)

        // Waveform view setup: seek/scrub callbacks
        waveformView.onSeek = { [weak self] progress in
            self?.selectionFeedback.selectionChanged()
            self?.seekPlayback(to: progress)
        }
        waveformView.onScrub = { [weak self] progress in
            self?.selectionFeedback.selectionChanged()
            self?.seekPlayback(to: progress)
        }

        // Playback time label
        playbackTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        playbackTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        playbackTimeLabel.textColor = AppColors.secondaryText
        playbackTimeLabel.textAlignment = .center
        playbackTimeLabel.adjustsFontForContentSizeCategory = true
        view.addSubview(playbackTimeLabel)

        // Play/pause button
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.backgroundColor = AppColors.primaryAccent
        playPauseButton.layer.cornerRadius = 40
        playPauseButton.layer.cornerCurve = .continuous
        playPauseButton.applyAdaptiveShadow(radius: 8, opacity: 0.15)
        playPauseButton.isAccessibilityElement = true
        playPauseButton.accessibilityLabel = "Play"
        playPauseButton.accessibilityTraits = .button
        playPauseButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(playPauseTapped)))
        view.addSubview(playPauseButton)

        playPauseIcon.translatesAutoresizingMaskIntoConstraints = false
        playPauseIcon.contentMode = .scaleAspectFit
        playPauseIcon.tintColor = .white
        playPauseIcon.image = UIImage(systemName: "play.fill")
        playPauseIcon.isAccessibilityElement = false
        playPauseButton.addSubview(playPauseIcon)

        // Re-record button
        reRecordButton.translatesAutoresizingMaskIntoConstraints = false
        reRecordButton.setTitle("Re-record", for: .normal)
        reRecordButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        reRecordButton.setTitleColor(AppColors.primaryText, for: .normal)
        reRecordButton.backgroundColor = AppColors.tertiaryBackground
        reRecordButton.layer.cornerRadius = 14
        reRecordButton.layer.cornerCurve = .continuous
        reRecordButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 24, bottom: 14, right: 24)
        reRecordButton.addTarget(self, action: #selector(reRecordTapped), for: .touchUpInside)
        reRecordButton.accessibilityHint = "Discard this recording and start over"
        view.addSubview(reRecordButton)

        // Use recording button
        useRecordingButton.translatesAutoresizingMaskIntoConstraints = false
        useRecordingButton.setTitle("Use Recording", for: .normal)
        useRecordingButton.titleLabel?.font = .preferredFont(forTextStyle: .body, compatibleWith: UITraitCollection(legibilityWeight: .bold))
        useRecordingButton.setTitleColor(.white, for: .normal)
        useRecordingButton.backgroundColor = AppColors.primaryAccent
        useRecordingButton.layer.cornerRadius = 14
        useRecordingButton.layer.cornerCurve = .continuous
        useRecordingButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 24, bottom: 14, right: 24)
        useRecordingButton.addTarget(self, action: #selector(useRecordingTapped), for: .touchUpInside)
        view.addSubview(useRecordingButton)
    }

    // MARK: - Constraints

    private func buildConstraints() {
        let guide = view.safeAreaLayoutGuide
        let margin: CGFloat = 24

        // Volume meter fill - width will be updated dynamically
        let fillWidth = volumeMeterFill.widthAnchor.constraint(equalToConstant: 0)
        fillWidth.identifier = "volumeFillWidth"

        // -- Ready constraints --
        readyConstraints = [
            glowRingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            glowRingView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            glowRingView.widthAnchor.constraint(equalToConstant: 208),
            glowRingView.heightAnchor.constraint(equalToConstant: 208),

            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            recordButton.widthAnchor.constraint(equalToConstant: 160),
            recordButton.heightAnchor.constraint(equalToConstant: 160),

            recordButtonIcon.centerXAnchor.constraint(equalTo: recordButton.centerXAnchor),
            recordButtonIcon.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),
            recordButtonIcon.widthAnchor.constraint(equalToConstant: 60),
            recordButtonIcon.heightAnchor.constraint(equalToConstant: 60),

            hintLabel.topAnchor.constraint(equalTo: recordButton.bottomAnchor, constant: 28),
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: margin),

            secondaryHintLabel.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 8),
            secondaryHintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            secondaryHintLabel.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: margin),
        ]

        // -- Recording constraints --
        recordingConstraints = [
            recDot.topAnchor.constraint(equalTo: guide.topAnchor, constant: 20),
            recDot.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: margin),
            recDot.widthAnchor.constraint(equalToConstant: 10),
            recDot.heightAnchor.constraint(equalToConstant: 10),

            recLabel.centerYAnchor.constraint(equalTo: recDot.centerYAnchor),
            recLabel.leadingAnchor.constraint(equalTo: recDot.trailingAnchor, constant: 6),

            timerLabel.topAnchor.constraint(equalTo: recDot.bottomAnchor, constant: 24),
            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            waveformView.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 32),
            waveformView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: margin),
            waveformView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -margin),
            waveformView.heightAnchor.constraint(equalToConstant: 140),

            volumeMeterTrack.topAnchor.constraint(equalTo: waveformView.bottomAnchor, constant: 20),
            volumeMeterTrack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: margin),
            volumeMeterTrack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -margin),
            volumeMeterTrack.heightAnchor.constraint(equalToConstant: 4),

            volumeMeterFill.leadingAnchor.constraint(equalTo: volumeMeterTrack.leadingAnchor),
            volumeMeterFill.topAnchor.constraint(equalTo: volumeMeterTrack.topAnchor),
            volumeMeterFill.bottomAnchor.constraint(equalTo: volumeMeterTrack.bottomAnchor),
            fillWidth,

            stopButton.topAnchor.constraint(equalTo: volumeMeterTrack.bottomAnchor, constant: 40),
            stopButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stopButton.widthAnchor.constraint(equalToConstant: 120),
            stopButton.heightAnchor.constraint(equalToConstant: 120),

            stopButtonIcon.centerXAnchor.constraint(equalTo: stopButton.centerXAnchor),
            stopButtonIcon.centerYAnchor.constraint(equalTo: stopButton.centerYAnchor),
            stopButtonIcon.widthAnchor.constraint(equalToConstant: 44),
            stopButtonIcon.heightAnchor.constraint(equalToConstant: 44),
        ]

        // -- Review constraints --
        reviewConstraints = [
            completeTitleLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 24),
            completeTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            durationLabel.topAnchor.constraint(equalTo: completeTitleLabel.bottomAnchor, constant: 6),
            durationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            waveformView.topAnchor.constraint(equalTo: durationLabel.bottomAnchor, constant: 28),
            waveformView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: margin),
            waveformView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -margin),
            waveformView.heightAnchor.constraint(equalToConstant: 140),

            playbackTimeLabel.topAnchor.constraint(equalTo: waveformView.bottomAnchor, constant: 14),
            playbackTimeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            playPauseButton.topAnchor.constraint(equalTo: playbackTimeLabel.bottomAnchor, constant: 24),
            playPauseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 80),
            playPauseButton.heightAnchor.constraint(equalToConstant: 80),

            playPauseIcon.centerXAnchor.constraint(equalTo: playPauseButton.centerXAnchor),
            playPauseIcon.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            playPauseIcon.widthAnchor.constraint(equalToConstant: 32),
            playPauseIcon.heightAnchor.constraint(equalToConstant: 32),

            reRecordButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: margin),
            reRecordButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -24),
            reRecordButton.heightAnchor.constraint(equalToConstant: 50),

            useRecordingButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -margin),
            useRecordingButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -24),
            useRecordingButton.heightAnchor.constraint(equalToConstant: 50),
            useRecordingButton.leadingAnchor.constraint(equalTo: reRecordButton.trailingAnchor, constant: 12),
            useRecordingButton.widthAnchor.constraint(equalTo: reRecordButton.widthAnchor),
        ]
    }

    // MARK: - State Transitions

    private func transitionState(from oldState: RecorderState, to newState: RecorderState) {
        // Handled by applyState (called from actions)
    }

    private func applyState(_ newState: RecorderState, animated: Bool) {
        let allComponents: [UIView] = [
            // ready
            recordButton, glowRingView, hintLabel, secondaryHintLabel,
            // recording
            timerLabel, waveformView, volumeMeterTrack, stopButton, recDot, recLabel,
            // review
            completeTitleLabel, durationLabel, playbackTimeLabel, playPauseButton,
            reRecordButton, useRecordingButton
        ]

        let readyViews: [UIView] = [recordButton, glowRingView, hintLabel, secondaryHintLabel]
        let recordingViews: [UIView] = [timerLabel, waveformView, volumeMeterTrack, stopButton, recDot, recLabel]
        let reviewViews: [UIView] = [completeTitleLabel, durationLabel, waveformView,
                                      playbackTimeLabel, playPauseButton, reRecordButton, useRecordingButton]

        let activeViews: [UIView]
        let activeConstraints: [NSLayoutConstraint]

        switch newState {
        case .ready:
            activeViews = readyViews
            activeConstraints = readyConstraints
        case .recording:
            activeViews = recordingViews
            activeConstraints = recordingConstraints
        case .review:
            activeViews = reviewViews
            activeConstraints = reviewConstraints
        }

        // Deactivate all constraint groups
        NSLayoutConstraint.deactivate(readyConstraints)
        NSLayoutConstraint.deactivate(recordingConstraints)
        NSLayoutConstraint.deactivate(reviewConstraints)

        let hideViews = allComponents.filter { !activeViews.contains($0) }
        let showViews = activeViews

        if animated {
            // Fade out hidden views, fade in active views
            showViews.forEach { $0.alpha = 0; $0.isHidden = false }
            NSLayoutConstraint.activate(activeConstraints)
            view.setNeedsLayout()

            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8,
                           initialSpringVelocity: 0, options: [.allowUserInteraction]) {
                hideViews.forEach { $0.alpha = 0 }
                showViews.forEach { $0.alpha = 1 }
                self.view.layoutIfNeeded()
            } completion: { _ in
                hideViews.forEach { $0.isHidden = true }
            }
        } else {
            hideViews.forEach { $0.isHidden = true; $0.alpha = 0 }
            showViews.forEach { $0.isHidden = false; $0.alpha = 1 }
            NSLayoutConstraint.activate(activeConstraints)
        }
    }

    // MARK: - Actions

    @objc private func recordButtonTapped() {
        mediumImpact.impactOccurred()
        startRecording()
    }

    @objc private func stopButtonTapped() {
        mediumImpact.impactOccurred()
        enterReviewState()
    }

    @objc private func playPauseTapped() {
        lightImpact.impactOccurred()
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    @objc private func reRecordTapped() {
        let alert = UIAlertController(
            title: "Re-record?",
            message: "This will discard the current recording.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Re-record", style: .destructive) { [weak self] _ in
            self?.lightImpact.impactOccurred()
            self?.discardAndRestart()
        })
        present(alert, animated: true)
    }

    @objc private func useRecordingTapped() {
        guard !didEmitCallback, let url = recordedURL else { return }
        didEmitCallback = true
        stopPlayback()

        successNotification.notificationOccurred(.success)
        showSuccessFlash(on: useRecordingButton)

        recordedURL = nil
        do { try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) } catch {}

        onFinished?(url)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }

    // MARK: - Recording Logic

    private func startRecording() {
        Task { @MainActor in
            let granted = await requestMicPermission()
            guard granted else {
                showMicDeniedAlert()
                return
            }

            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                try session.setActive(true)

                let url = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent(UUID().uuidString + ".m4a")
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]

                recordedURL = url

                let rec = try AVAudioRecorder(url: url, settings: settings)
                rec.delegate = self
                rec.isMeteringEnabled = true
                rec.record()
                recorder = rec

                state = .recording
                applyState(.recording, animated: true)
                startRecordingTimers()
                startRecDotPulse()

            } catch {
                showError("Failed to start recording: \(error.localizedDescription)")
            }
        }
    }

    private func enterReviewState() {
        stopRecorderAndTimers()

        waveformView.switchToReviewMode()

        guard let url = recordedURL else { return }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
        } catch {
            showError("Could not load recording: \(error.localizedDescription)")
            return
        }

        let duration = player?.duration ?? 0
        durationLabel.text = formatTime(duration)
        playbackTimeLabel.text = "\(formatTime(0)) / \(formatTime(duration))"

        successNotification.notificationOccurred(.success)

        state = .review
        applyState(.review, animated: true)
    }

    private func discardAndRestart() {
        stopPlayback()

        // Delete temp file
        if let url = recordedURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordedURL = nil
        player = nil

        waveformView.reset()
        timerLabel.text = "0:00"

        state = .ready
        applyState(.ready, animated: true)

        // Restart breathing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.startBreathingAnimation()
            self?.scheduleSecondaryHint()
        }
    }

    private func stopRecorderAndTimers() {
        recorder?.stop()
        recorder = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        amplitudeTimer?.invalidate()
        amplitudeTimer = nil
    }

    private func requestMicPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }

    // MARK: - Timers

    private func startRecordingTimers() {
        recordingStartTime = Date()

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartTime else { return }
            self.updateTimerDisplay(from: start)
        }

        amplitudeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateAmplitude()
        }
    }

    private func updateTimerDisplay(from start: Date) {
        let elapsed = Date().timeIntervalSince(start)
        timerLabel.text = formatTime(elapsed)
    }

    private func updateAmplitude() {
        guard let recorder else { return }
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)
        let normalized = normalizeDB(db)

        waveformView.appendSample(normalized)

        // Volume meter fill
        let trackWidth = volumeMeterTrack.bounds.width
        let fillWidth = trackWidth * CGFloat(normalized)
        if let constraint = volumeMeterTrack.constraints.first(where: { $0.identifier == "volumeFillWidth" }) ??
           volumeMeterFill.superview?.constraints.first(where: { $0.identifier == "volumeFillWidth" }) {
            constraint.constant = fillWidth
        } else {
            // Find in recording constraints
            for c in recordingConstraints where c.identifier == "volumeFillWidth" {
                c.constant = fillWidth
                break
            }
        }
    }

    private func normalizeDB(_ db: Float) -> Float {
        let minDB: Float = -60
        let maxDB: Float = 0
        return max(0, min(1, (db - minDB) / (maxDB - minDB)))
    }

    // MARK: - Playback

    private func startPlayback() {
        guard let player else { return }
        player.play()
        isPlaying = true
        playPauseIcon.image = UIImage(systemName: "pause.fill")
        playPauseButton.accessibilityLabel = "Pause"

        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            self?.updatePlaybackProgress()
        }
    }

    private func pausePlayback() {
        player?.pause()
        isPlaying = false
        playPauseIcon.image = UIImage(systemName: "play.fill")
        playPauseButton.accessibilityLabel = "Play"
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func stopPlayback() {
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
        playPauseIcon.image = UIImage(systemName: "play.fill")
        playPauseButton.accessibilityLabel = "Play"
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func updatePlaybackProgress() {
        guard let player else { return }
        let duration = player.duration
        guard duration > 0 else { return }

        let current = player.currentTime
        let progress = CGFloat(current / duration)
        waveformView.setPlaybackProgress(progress)
        playbackTimeLabel.text = "\(formatTime(current)) / \(formatTime(duration))"

        // Auto-stop at end
        if !player.isPlaying && isPlaying {
            pausePlayback()
            waveformView.setPlaybackProgress(1.0)
        }
    }

    private func seekPlayback(to progress: CGFloat) {
        guard let player else { return }
        let time = TimeInterval(progress) * player.duration
        player.currentTime = time
        waveformView.setPlaybackProgress(progress)
        playbackTimeLabel.text = "\(formatTime(time)) / \(formatTime(player.duration))"
    }

    // MARK: - Animations

    private func startBreathingAnimation() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        recordButton.layer.removeAllAnimations()
        glowRingView.layer.removeAllAnimations()

        UIView.animate(withDuration: 2.5, delay: 0,
                       options: [.repeat, .autoreverse, .allowUserInteraction, .curveEaseInOut]) {
            self.recordButton.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
            self.glowRingView.alpha = 0.45
        }
    }

    private func stopBreathingAnimation() {
        UIView.animate(withDuration: 0.3, delay: 0, options: .beginFromCurrentState) {
            self.recordButton.transform = .identity
            self.glowRingView.alpha = 0.3
        }
    }

    private func startRecDotPulse() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        recDot.layer.removeAllAnimations()
        UIView.animate(withDuration: 1.0, delay: 0,
                       options: [.repeat, .autoreverse, .allowUserInteraction]) {
            self.recDot.alpha = 0.3
        }
    }

    private func showSuccessFlash(on button: UIView) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        UIView.animate(withDuration: 0.3, delay: 0, options: .allowUserInteraction) {
            button.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        } completion: { _ in
            UIView.animate(withDuration: 0.3) {
                button.transform = .identity
            }
        }
    }

    private func scheduleSecondaryHint() {
        secondaryHintLabel.alpha = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, self.state == .ready else { return }
            UIView.animate(withDuration: 0.5) {
                self.secondaryHintLabel.alpha = 1
            }
        }
    }

    // MARK: - Alerts

    private func showMicDeniedAlert() {
        let alert = UIAlertController(
            title: "Microphone Access Required",
            message: "Please enable microphone access in Settings to record audio.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        present(alert, animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Recording Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Helpers

    private func prepareHaptics() {
        lightImpact.prepare()
        mediumImpact.prepare()
        selectionFeedback.prepare()
        successNotification.prepare()
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - AVAudioRecorderDelegate

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        showError("Recording error: \(error?.localizedDescription ?? "Unknown")")
        stopRecorderAndTimers()
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // System-initiated stop (interruption, etc.)
        guard state == .recording else { return }
        self.recorder = nil
        if flag {
            enterReviewState()
        } else {
            showError("Recording failed")
            discardAndRestart()
        }
    }
}
