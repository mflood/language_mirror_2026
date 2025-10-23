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
    var onFinished: ((URL) -> Void)?
    var onCancelled: (() -> Void)?  // optional hook if parent cares

    private var recorder: AVAudioRecorder?
    private var recordedURL: URL?
    private var didEmitCallback = false
    
    // MARK: - UI Components
    
    private let timerLabel = UILabel()
    private let buttonContainer = UIView()
    private let buttonIcon = UIImageView()
    private let amplitudeBar = UIView()
    private var amplitudeBarHeightConstraint: NSLayoutConstraint!
    
    // MARK: - Recording State
    
    private var recordingStartTime: Date?
    private var recordingTimer: Timer?
    private var amplitudeTimer: Timer?
    private var isRecording = false
    
    // MARK: - Haptic Feedback
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let successNotification = UINotificationFeedbackGenerator()
    
    // MARK: - Init
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupHapticFeedback()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = AppColors.calmBackground
        
        // Timer label
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 34, weight: .semibold)
        timerLabel.textColor = AppColors.primaryText
        timerLabel.textAlignment = .center
        timerLabel.text = "00:00"
        timerLabel.isHidden = true
        timerLabel.adjustsFontForContentSizeCategory = true
        timerLabel.accessibilityLabel = "Recording duration"
        timerLabel.accessibilityTraits = .updatesFrequently
        view.addSubview(timerLabel)
        
        // Button container (circular)
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.backgroundColor = AppColors.primaryAccent
        buttonContainer.layer.cornerRadius = 80
        buttonContainer.layer.cornerCurve = .continuous
        buttonContainer.applyAdaptiveShadow(radius: 12, opacity: 0.2)
        buttonContainer.isAccessibilityElement = true
        buttonContainer.accessibilityLabel = "Start recording"
        buttonContainer.accessibilityTraits = .button
        buttonContainer.accessibilityHint = "Double tap to start recording"
        view.addSubview(buttonContainer)
        
        // Button icon
        buttonIcon.translatesAutoresizingMaskIntoConstraints = false
        buttonIcon.contentMode = .scaleAspectFit
        buttonIcon.tintColor = .white
        buttonIcon.image = UIImage(systemName: "mic.fill")
        buttonIcon.isAccessibilityElement = false // Handled by container
        buttonContainer.addSubview(buttonIcon)
        
        // Amplitude bar
        amplitudeBar.translatesAutoresizingMaskIntoConstraints = false
        amplitudeBar.backgroundColor = AppColors.primaryAccent
        amplitudeBar.layer.cornerRadius = 2
        amplitudeBar.layer.cornerCurve = .continuous
        amplitudeBar.isHidden = true
        amplitudeBar.isAccessibilityElement = true
        amplitudeBar.accessibilityLabel = "Audio level indicator"
        amplitudeBar.accessibilityTraits = .updatesFrequently
        view.addSubview(amplitudeBar)
        
        // Tap gesture for button
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(buttonTapped))
        buttonContainer.addGestureRecognizer(tapGesture)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        // Create amplitude bar height constraint
        amplitudeBarHeightConstraint = amplitudeBar.heightAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            // Timer label
            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            timerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            
            // Button container (160x160)
            buttonContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            buttonContainer.widthAnchor.constraint(equalToConstant: 160),
            buttonContainer.heightAnchor.constraint(equalToConstant: 160),
            
            // Button icon (60x60)
            buttonIcon.centerXAnchor.constraint(equalTo: buttonContainer.centerXAnchor),
            buttonIcon.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            buttonIcon.widthAnchor.constraint(equalToConstant: 60),
            buttonIcon.heightAnchor.constraint(equalToConstant: 60),
            
            // Amplitude bar
            amplitudeBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            amplitudeBar.topAnchor.constraint(equalTo: buttonContainer.bottomAnchor, constant: 40),
            amplitudeBar.widthAnchor.constraint(equalToConstant: 200),
            amplitudeBarHeightConstraint
        ])
    }
    
    private func setupHapticFeedback() {
        lightImpact.prepare()
        mediumImpact.prepare()
        successNotification.prepare()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Auto-save if recording (don't delete)
        if isRecording {
            stopRecording()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Clean up timers
        stopRecordingTimer()
        stopAmplitudeMonitoring()
    }
    
    // MARK: - Button Actions
    
    @objc private func buttonTapped() {
        mediumImpact.impactOccurred()
        
        if !isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }
    
    // MARK: - Recording Logic
    
    private func startRecording() {
        Task { @MainActor in
            let granted = await requestMicPermission()
            guard granted else {
                showError("Microphone permission denied")
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
                
                // Update UI for recording state
                updateUIForRecordingState(isRecording: true)
                startRecordingTimer()
                startAmplitudeMonitoring()
                
            } catch {
                showError("Failed to start recording: \(error.localizedDescription)")
            }
        }
    }
    
    private func stopRecording() {
        recorder?.stop()
        recorder = nil
        stopRecordingTimer()
        stopAmplitudeMonitoring()
        updateUIForRecordingState(isRecording: false)
        finalizeAndEmitIfNeeded()
    }

    private func requestMicPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }
    
    // MARK: - UI Updates
    
    private func updateUIForRecordingState(isRecording: Bool) {
        self.isRecording = isRecording
        
        if isRecording {
            // Show recording UI
            timerLabel.isHidden = false
            amplitudeBar.isHidden = false
            
            // Update button appearance
            buttonContainer.backgroundColor = .systemRed
            buttonIcon.image = UIImage(systemName: "stop.fill")
            
            // Update accessibility
            buttonContainer.accessibilityLabel = "Stop recording"
            buttonContainer.accessibilityHint = "Double tap to stop recording"
            
            // Start pulsing animation
            startPulsingAnimation()
            
        } else {
            // Hide recording UI
            timerLabel.isHidden = true
            amplitudeBar.isHidden = true
            
            // Update button appearance
            buttonContainer.backgroundColor = AppColors.primaryAccent
            buttonIcon.image = UIImage(systemName: "mic.fill")
            
            // Update accessibility
            buttonContainer.accessibilityLabel = "Start recording"
            buttonContainer.accessibilityHint = "Double tap to start recording"
            
            // Stop pulsing animation
            stopPulsingAnimation()
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Recording Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Timer Management
    
    private func startRecordingTimer() {
        recordingStartTime = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
    }
    
    private func updateTimer() {
        guard let startTime = recordingStartTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        
        if minutes > 0 {
            timerLabel.text = String(format: "%d:%02d", minutes, seconds)
        } else {
            timerLabel.text = String(format: "0:%02d", seconds)
        }
    }
    
    // MARK: - Amplitude Monitoring
    
    private func startAmplitudeMonitoring() {
        amplitudeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateAmplitude()
        }
    }
    
    private func stopAmplitudeMonitoring() {
        amplitudeTimer?.invalidate()
        amplitudeTimer = nil
        amplitudeBarHeightConstraint.constant = 0
        view.layoutIfNeeded()
    }
    
    private func updateAmplitude() {
        guard let recorder = recorder else { return }
        
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)
        let normalized = normalizeDB(db)
        
        // Animate amplitude bar height (0-60pt range)
        amplitudeBarHeightConstraint.constant = CGFloat(normalized * 60)
        
        UIView.animate(withDuration: 0.05, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func normalizeDB(_ db: Float) -> Float {
        // Convert dB to 0-1 range
        // Typical range: -60dB (quiet) to 0dB (loud)
        let minDB: Float = -60
        let maxDB: Float = 0
        let normalized = (db - minDB) / (maxDB - minDB)
        return max(0, min(1, normalized))
    }
    
    // MARK: - Animations
    
    private func startPulsingAnimation() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        
        UIView.animate(withDuration: 1.5, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction]) {
            self.buttonContainer.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }
    }
    
    private func stopPulsingAnimation() {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.beginFromCurrentState]) {
            self.buttonContainer.transform = .identity
        }
    }
    
    private func showSuccessAnimation() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        
        UIView.animate(withDuration: 0.3, delay: 0, options: [.allowUserInteraction]) {
            self.buttonContainer.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        } completion: { _ in
            UIView.animate(withDuration: 0.3) {
                self.buttonContainer.transform = .identity
            }
        }
    }
    
    // MARK: - Recording Finalization
    
    private func finalizeAndEmitIfNeeded() {
        guard !didEmitCallback, let url = recordedURL else { return }
        didEmitCallback = true

        recordedURL = nil
        do { try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) } catch {}

        // Show success feedback
        successNotification.notificationOccurred(.success)
        showSuccessAnimation()
        
        // Generate title with current date
        let title = recordingTitle()
        
        // Call completion with URL
        onFinished?(url)
        
        // Navigate back after brief delay to show success animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    private func recordingTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Recording \(formatter.string(from: Date()))"
    }
    
    // MARK: - AVAudioRecorderDelegate
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        showError("Recording error: \(error?.localizedDescription ?? "Unknown")")
        stopRecording()
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            // System finished recording successfully
            self.recorder = nil
            stopRecordingTimer()
            stopAmplitudeMonitoring()
            updateUIForRecordingState(isRecording: false)
            finalizeAndEmitIfNeeded()
        } else {
            // Unsuccessful finish
            showError("Recording failed")
            stopRecording()
        }
    }
}

