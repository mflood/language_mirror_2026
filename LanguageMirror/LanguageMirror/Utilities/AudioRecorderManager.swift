//
//  AudioRecorderManager.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/29/25.
//
// A self‑contained audio recording utility that notifies its delegate about
// amplitude samples and lifecycle events. Uses AVAudioEngine for low‑latency
// capture and writes directly to a CAF file in the app’s documents folder.

import AVFoundation
import UIKit

// MARK: Delegate
protocol AudioRecorderManagerDelegate: AnyObject {
    /// Waveform power samples (0…1) captured in real time
    func audioRecorder(_ recorder: AudioRecorderManager, didCaptureLevels levels: [Float])
    /// Called whenever the recorder’s high‑level state changes
    func audioRecorder(_ recorder: AudioRecorderManager, didChangeState state: AudioRecorderManager.State)
    /// One‑shot callback when a recording session ends
    func audioRecorderDidFinishRecording(_ recorder: AudioRecorderManager, successfully flag: Bool, error: Error?)
    /// Fired roughly once per second while recording so UI can show a running timer
    func audioRecorder(_ recorder: AudioRecorderManager, didUpdateElapsedTime seconds: TimeInterval)
}

final class AudioRecorderManager: NSObject {
    enum State: Equatable { // ✅ Equatable conformance enables == / !=
        case idle
        case recording
        case stopped
        case error(Error)

        // For == on `error` we only check the case, not the Error detail
        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.recording, .recording), (.stopped, .stopped): return true
            case (.error, .error): return true
            default: return false
            }
        }
    }

    // MARK: Public
    weak var delegate: AudioRecorderManagerDelegate?
    private(set) var state: State = .idle { didSet { delegate?.audioRecorder(self, didChangeState: state) } }

    // MARK: Private engine plumbing
    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private var file: AVAudioFile?
    private var recordingURL: URL?

    private let ioQueue = DispatchQueue(label: "AudioRecorderIO")
    private var tickTimer: DispatchSourceTimer?
    private var startTime: Date?

    override init() {
        super.init()
        configureSession()
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        tickTimer?.cancel()
    }

    // MARK: – Control
    func startRecording() throws {
        guard state != .recording else { return }

        try configureEngineIfNeeded()
        try engine.start()

        startTime = Date()
        scheduleElapsedTimeTicks()
        state = .recording
    }

    func stopRecording() {
        guard state == .recording else { return }
        engine.stop()
        mixer.removeTap(onBus: 0)
        tickTimer?.cancel(); tickTimer = nil
        ioQueue.sync { try? file?.close() }
        state = .stopped
        delegate?.audioRecorderDidFinishRecording(self, successfully: true, error: nil)
    }

    // MARK: – Timing helpers
    private func scheduleElapsedTimeTicks() {
        tickTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 1)
        timer.setEventHandler { [weak self] in
            guard let self, self.state == .recording, let startTime else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            self.delegate?.audioRecorder(self, didUpdateElapsedTime: elapsed)
        }
        timer.resume()
        tickTimer = timer
    }

    // MARK: – Session & engine setup
    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: [])
        } catch {
            state = .error(error)
        }
    }

    private func configureEngineIfNeeded() throws {
        guard file == nil else { return } // already configured for this run

        let input = engine.inputNode
        engine.attach(mixer)
        engine.connect(input, to: mixer, format: input.inputFormat(forBus: 0))

        let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filename = "Recording_\(ISO8601DateFormatter().string(from: .now)).caf"
        recordingURL = docURL.appendingPathComponent(filename)
        let format = mixer.outputFormat(forBus: 0)
        file = try AVAudioFile(forWriting: recordingURL!, settings: format.settings)

        mixer.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.ioQueue.async { try? self.file?.write(from: buffer) }
            self.process(buffer: buffer)
        }
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let length = Int(buffer.frameLength)
        let stride = 512
        var samples: [Float] = []
        var i = 0
        while i < length {
            let end = min(i + stride, length)
            var maxVal: Float = 0
            for j in i..<end { maxVal = max(maxVal, abs(channel[j])) }
            samples.append(maxVal)
            i += stride
        }
        DispatchQueue.main.async { self.delegate?.audioRecorder(self, didCaptureLevels: samples) }
    }

    // MARK: – Notifications
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeVal = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeVal) else { return }
        switch type {
        case .began: stopRecording()
        case .ended:
            if let optionsVal = info[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsVal).contains(.shouldResume) {
                try? startRecording()
            }
        @unknown default: break
        }
    }
    @objc private func handleRouteChange(_ note: Notification) { stopRecording() }
    @objc private func handleDidEnterBackground() { /* policy */ }
    @objc private func handleWillEnterForeground() { }
}
