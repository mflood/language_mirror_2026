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
    private let status = UILabel()
    private let button = UIButton(type: .system)
    
     private var recordedURL: URL?
     private var didEmitCallback = false

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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // If user navigates back while recording, treat as cancel: stop & delete.
        if recorder != nil {
            cancelRecordingAndCleanup()
        }
    }

    @objc private func toggle() {
        if recorder == nil {
            start()
        } else {
            stopAndFinish()
        }
    }

    
    private func start() {
        Task { @MainActor in
            let granted = await requestMicPermission()
            guard granted else {
                self.status.text = "Mic permission denied"
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
                
                self.recordedURL = url
                
                let rec = try AVAudioRecorder(url: url, settings: settings)
                rec.delegate = self
                rec.record()
                self.recorder = rec

                self.status.text = "Recording…"
                self.button.setTitle("Stop", for: .normal)
                
            } catch {
                self.status.text = "Failed: \(error.localizedDescription)"
            }
        }
    }

    private func requestMicPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }
    
    private func finalizeAndEmitIfNeeded() {
        guard !didEmitCallback, let url = recordedURL else { return }
        didEmitCallback = true

        recordedURL = nil
        do { try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) } catch {}

        status.text = "Saved"
        button.setTitle("Start Recording", for: .normal)

        onFinished?(url)
        navigationController?.popViewController(animated: true)
    }

    private func stopAndFinish() {
        recorder?.stop()
        recorder = nil
        finalizeAndEmitIfNeeded()
    }

    private func cancelRecordingAndCleanup() {
        // Called on “back” mid-recording or other cancellation paths.
        recorder?.stop()
        recorder = nil

        if let url = recordedURL {
            try? FileManager.default.removeItem(at: url)  // discard incomplete take
        }
        recordedURL = nil
        do { try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) } catch {}

        if !didEmitCallback { onCancelled?() }
        didEmitCallback = true
    }
    
    
    // MARK: AVAudioRecorderDelegate (robustness)
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        status.text = "Encode error: \(error?.localizedDescription ?? "Unknown")"
        cancelRecordingAndCleanup()
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            // System finished our recording successfully (not user-initiated?) — emit once.
            // If the user tapped Stop, stopAndFinish() already handled it and set didEmitCallback.
            self.recorder = nil
            finalizeAndEmitIfNeeded()
        } else {
            // Unsuccessful finish: clean up and notify cancel.
            cancelRecordingAndCleanup()
        }
    }
    
}
