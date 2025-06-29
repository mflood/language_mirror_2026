//
//  AudioRecorderViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/29/25.
//
import UIKit

final class RecorderViewController: UIViewController {

    private let recordButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let timeLabel = UILabel()
    private let waveformView = WaveformView()
    private let recorder = AudioRecorderManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        recorder.delegate = self
        configureUI()
        updateStatus("Idle")
        updateTime(0)
    }

    private func configureUI() {
        recordButton.configuration = .filled()
        recordButton.configuration?.title = "Record"
        recordButton.addTarget(self, action: #selector(toggleRecording), for: .touchUpInside)
        [recordButton, statusLabel, timeLabel, waveformView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.textAlignment = .center
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        timeLabel.textAlignment = .center

        view.addSubview(waveformView)
        view.addSubview(recordButton)
        view.addSubview(statusLabel)
        view.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            waveformView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            waveformView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            waveformView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            waveformView.heightAnchor.constraint(equalToConstant: 120),

            statusLabel.topAnchor.constraint(equalTo: waveformView.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: waveformView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: waveformView.trailingAnchor),

            timeLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: waveformView.leadingAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: waveformView.trailingAnchor),

            recordButton.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 24),
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    @objc private func toggleRecording() {
        switch recorder.state {
        case .recording: recorder.stopRecording()
        default: try? recorder.startRecording()
        }
    }

    private func updateStatus(_ text: String) { statusLabel.text = text }

    private func updateTime(_ seconds: TimeInterval) {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        timeLabel.text = String(format: "%02d:%02d", mins, secs)
    }

    private func updateButtonAppearance() {
        let isRec = recorder.state == .recording
        recordButton.configuration?.title = isRec ? "Stop" : "Record"
        recordButton.configuration?.baseBackgroundColor = isRec ? .systemRed : .systemBlue
    }

    private func presentAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: – AudioRecorderManagerDelegate
extension RecorderViewController: AudioRecorderManagerDelegate {
    func audioRecorder(_ recorder: AudioRecorderManager, didChangeState state: AudioRecorderManager.State) {
        switch state {
        case .idle: updateStatus("Idle")
        case .recording: updateStatus("Recording …")
        case .stopped: updateStatus("Stopped")
        case .error(let err): updateStatus("Error"); presentAlert(message: err.localizedDescription)
        }
        updateButtonAppearance()
    }

    func audioRecorder(_ recorder: AudioRecorderManager, didCaptureLevels levels: [Float]) { waveformView.update(with: levels) }

    func audioRecorder(_ recorder: AudioRecorderManager, didUpdateElapsedTime seconds: TimeInterval) { updateTime(seconds) }

    func audioRecorderDidFinishRecording(_ recorder: AudioRecorderManager, successfully flag: Bool, error: Error?) {
        if let error { presentAlert(message: error.localizedDescription) }
    }
}
