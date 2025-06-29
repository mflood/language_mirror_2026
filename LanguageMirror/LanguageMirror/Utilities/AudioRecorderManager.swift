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

protocol AudioRecorderManagerDelegate: AnyObject {
    /// Called every time a batch of level samples is ready
    func audioRecorder(_ recorder: AudioRecorderManager, didCaptureLevels levels: [Float])
    /// Called when recording stops – either intentionally or due to an error / interruption
    func audioRecorderDidFinishRecording(_ recorder: AudioRecorderManager, successfully flag: Bool, error: Error?)
}



final class AudioRecorderManager: NSObject {
    weak var delegate: AudioRecorderManagerDelegate?

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()   // Tap here for level metering
    private var file: AVAudioFile?
    private var recordingURL: URL?
    private var isConfigured = false

    private let ioQueue = DispatchQueue(label: "AudioRecorderIO")

    override init() {
        super.init()
        configureSession()
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Public API

    func startRecording() throws {
        if !isConfigured {
            try configureEngine()
        }

        guard !engine.isRunning else { return }
        try engine.start()
        isConfigured = true
    }

    func stopRecording() {
        engine.stop()
        mixer.removeTap(onBus: 0)
        ioQueue.sync {
            try? file?.close()
        }
        delegate?.audioRecorderDidFinishRecording(self, successfully: true, error: nil)
    }

    // MARK: Private helpers

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: [])
        } catch {
            delegate?.audioRecorderDidFinishRecording(self, successfully: false, error: error)
        }
    }

    private func configureEngine() throws {
        let input = engine.inputNode
        engine.attach(mixer)
        engine.connect(input, to: mixer, format: input.inputFormat(forBus: 0))

        let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filename = "Recording_\(ISO8601DateFormatter().string(from: .now)).caf"
        let url = docURL.appendingPathComponent(filename)
        recordingURL = url
        let format = mixer.outputFormat(forBus: 0)
        file = try AVAudioFile(forWriting: url, settings: format.settings)

        mixer.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.ioQueue.async {
                do {
                    try self.file?.write(from: buffer)
                } catch {
                    DispatchQueue.main.async {
                        self.delegate?.audioRecorderDidFinishRecording(self, successfully: false, error: error)
                    }
                }
            }
            self.process(buffer: buffer)
        }
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        let stride = 512
        var levels: [Float] = []
        var i = 0
        while i < frameLength {
            let start = i
            let end = min(i + stride, frameLength)
            var maxVal: Float = 0
            for j in start..<end {
                maxVal = max(maxVal, abs(channelData[j]))
            }
            levels.append(maxVal)
            i += stride
        }
        DispatchQueue.main.async {
            self.delegate?.audioRecorder(self, didCaptureLevels: levels)
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard
            let info = note.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            stopRecording()
        case .ended:
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt, AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                try? startRecording()
            }
        @unknown default: break
        }
    }

    @objc private func handleRouteChange(_ note: Notification) {
        // For example, stop if headphones unplugged
        stopRecording()
    }

    @objc private func handleDidEnterBackground() {
        // iOS will let us keep recording, but you might prefer to pause
        stopRecording()
    }

    @objc private func handleWillEnterForeground() {
        // Optionally resume
    }
}

// MARK: - WaveformView.swift
// Lightweight real‑time waveform renderer backed by CAShapeLayer.

import UIKit

final class WaveformView: UIView {
    private let shapeLayer = CAShapeLayer()
    private var levels: [Float] = []
    private let maxSamples = 300

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); commonInit() }

    private func commonInit() {
        layer.addSublayer(shapeLayer)
        shapeLayer.lineWidth = 2
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = tintColor.cgColor
    }

    func update(with newLevels: [Float]) {
        levels.append(contentsOf: newLevels)
        if levels.count > maxSamples {
            levels.removeFirst(levels.count - maxSamples)
        }
        setNeedsDisplay()
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        shapeLayer.strokeColor = tintColor.cgColor
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard !levels.isEmpty else { return }
        let path = UIBezierPath()
        let midY = bounds.midY
        let width = bounds.width
        let step = width / CGFloat(max(levels.count - 1, 1))
        for (i, level) in levels.enumerated() {
            let x = CGFloat(i) * step
            let y = midY - CGFloat(level) * midY
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        shapeLayer.path = path.cgPath
    }
}
