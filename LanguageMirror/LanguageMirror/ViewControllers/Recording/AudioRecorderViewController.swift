//
//  AudioRecorderViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/29/25.
//

import UIKit

final class RecorderViewController: UIViewController {

    private let recordButton = UIButton(type: .system)
    private let waveformView = WaveformView()
    private let recorder = AudioRecorderManager()
    private var isRecording = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        recorder.delegate = self
        configureUI()
    }

    private func configureUI() {
        recordButton.configuration = .filled()
        recordButton.configuration?.title = "Record"
        recordButton.addTarget(self, action: #selector(toggleRecording), for: .touchUpInside)
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        waveformView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(waveformView)
        view.addSubview(recordButton)

        NSLayoutConstraint.activate([
            waveformView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            waveformView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            waveformView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            waveformView.heightAnchor.constraint(equalToConstant: 120),

            recordButton.topAnchor.constraint(equalTo: waveformView.bottomAnchor, constant: 40),
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    @objc private func toggleRecording() {
        if isRecording {
            recorder.stopRecording()
        } else {
            do {
                try recorder.startRecording()
            } catch {
                presentAlert(message: "Recording failed: \(error.localizedDescription)")
            }
        }
        isRecording.toggle()
        updateButtonAppearance()
    }

    private func updateButtonAppearance() {
        recordButton.configuration?.title = isRecording ? "Stop" : "Record"
        recordButton.configuration?.baseBackgroundColor = isRecording ? .systemRed : .systemBlue
    }

    private func presentAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - AudioRecorderManagerDelegate

extension RecorderViewController: AudioRecorderManagerDelegate {
    func audioRecorder(_ recorder: AudioRecorderManager, didCaptureLevels levels: [Float]) {
        waveformView.update(with: levels)
    }

    func audioRecorderDidFinishRecording(_ recorder: AudioRecorderManager, successfully flag: Bool, error: Error?) {
        isRecording = false
        updateButtonAppearance()
        if let error {
            presentAlert(message: error.localizedDescription)
        }
    }
}
