//
//  AudioRecorderViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/18/25.
//

// path: Screens/AudioRecorderViewController.swift
import UIKit
import AVFoundation

final class AudioRecorderViewController: UIViewController, AVAudioRecorderDelegate {
    var onFinished: ((URL) -> Void)?

    private var recorder: AVAudioRecorder?
    private let status = UILabel()
    private let button = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Record"
        view.backgroundColor = .systemBackground
        status.translatesAutoresizingMaskIntoConstraints = false
        status.text = "Ready"
        status.textAlignment = .center

        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Start Recording", for: .normal)
        button.addTarget(self, action: #selector(toggle), for: .touchUpInside)

        view.addSubview(status)
        view.addSubview(button)
        NSLayoutConstraint.activate([
            status.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            status.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            button.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 20),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    @objc private func toggle() {
        if recorder == nil {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] ok in
            guard ok, let self else {
                DispatchQueue.main.async { self?.status.text = "Mic permission denied" }
                return
            }
            DispatchQueue.main.async {
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                    try AVAudioSession.sharedInstance().setActive(true)

                    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".m4a")
                    let settings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVSampleRateKey: 44100,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                    ]
                    self.recorder = try AVAudioRecorder(url: url, settings: settings)
                    self.recorder?.delegate = self
                    self.recorder?.record()

                    self.status.text = "Recording…"
                    self.button.setTitle("Stop", for: .normal)
                } catch {
                    self.status.text = "Failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func stop() {
        recorder?.stop()
        guard let url = recorder?.url else { return }
        recorder = nil
        status.text = "Saved"
        button.setTitle("Start Recording", for: .normal)
        onFinished?(url)
        navigationController?.popViewController(animated: true)
    }
}
