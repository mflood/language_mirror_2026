import UIKit
import AVFoundation
import Accelerate

class SiivAudioRecorderViewController: UIViewController {
    
    // MARK: - UI Components
    
    // Header
    @IBOutlet weak var headerTitleLabel: UILabel!
    // @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    
    // Recording Controls
    @IBOutlet weak var recordingControlsContainerView: UIView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var recordingStatusLabel: UILabel!
    @IBOutlet weak var recordingTimerLabel: UILabel!
    
    // Waveform Visualization
    @IBOutlet weak var waveformContainerView: UIView!
    @IBOutlet weak var waveformView: UIView!
    @IBOutlet weak var waveformScrollView: UIScrollView!
    @IBOutlet weak var waveformContentView: UIView!
    @IBOutlet weak var noAudioLabel: UILabel!
    
    // Playback Controls
    @IBOutlet weak var playbackControlsContainerView: UIView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var pausePlaybackButton: UIButton!
    @IBOutlet weak var stopPlaybackButton: UIButton!
    @IBOutlet weak var playbackProgressSlider: UISlider!
    @IBOutlet weak var playbackTimeLabel: UILabel!
    @IBOutlet weak var totalTimeLabel: UILabel!
    
    // Recording Settings
    @IBOutlet weak var settingsContainerView: UIView!
    @IBOutlet weak var settingsTitleLabel: UILabel!
    @IBOutlet weak var qualitySegmentedControl: UISegmentedControl!
    @IBOutlet weak var sampleRateLabel: UILabel!
    @IBOutlet weak var bitDepthLabel: UILabel!
    @IBOutlet weak var formatLabel: UILabel!
    
    // Recording List
    @IBOutlet weak var recordingsContainerView: UIView!
    @IBOutlet weak var recordingsTitleLabel: UILabel!
    @IBOutlet weak var recordingsTableView: UITableView!
    @IBOutlet weak var noRecordingsLabel: UILabel!
    
    // Loading Overlay
    @IBOutlet weak var loadingOverlayView: UIView!
    @IBOutlet weak var loadingActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var loadingLabel: UILabel!
    
    // MARK: - Properties
    weak var delegate: SiivAudioRecorderDelegate?
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingURL: URL?
    private var isRecording = false
    private var isPaused = false
    private var isPlaying = false
    private var recordingStartTime: Date?
    private var recordingTimer: Timer?
    private var playbackTimer: Timer?
    private var recordings: [Recording] = []
    private var waveformData: [Float] = []
    private var waveformLayer: CAShapeLayer?
    
    // Audio settings
    private var audioQuality: AudioQuality = .high
    private var sampleRate: Double = 44100.0
    private var bitDepth: Int = 16
    private var audioFormat: String = "AAC"
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupAudioSession()
        setupTableView()
        loadRecordings()
        setupWaveformView()
        updateSettingsDisplay()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkMicrophonePermission()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopRecording()
        stopPlayback()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        setupHeader()
        setupRecordingControls()
        setupWaveformVisualization()
        setupPlaybackControls()
        setupSettings()
        setupRecordingsList()
        setupLoadingOverlay()
    }
    
    private func setupHeader() {
        headerTitleLabel.text = "Audio Recorder"
        headerTitleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        headerTitleLabel.textColor = UIColor(named: "PrimaryText")
        
        //cancelButton.setTitle("Cancel", for: .normal)
        //cancelButton.setTitleColor(UIColor(named: "SecondaryText"), for: .normal)
        //cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        
        saveButton.setTitle("Save", for: .normal)
        saveButton.setTitleColor(UIColor(named: "PrimaryBlue"), for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        saveButton.isEnabled = false
    }
    
    private func setupRecordingControls() {
        recordingControlsContainerView.backgroundColor = .white
        recordingControlsContainerView.layer.cornerRadius = 12
        recordingControlsContainerView.layer.shadowColor = UIColor.black.cgColor
        recordingControlsContainerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        recordingControlsContainerView.layer.shadowRadius = 4
        recordingControlsContainerView.layer.shadowOpacity = 0.1
        
        // Record button
        recordButton.backgroundColor = UIColor(named: "SuccessGreen")
        recordButton.setTitleColor(.white, for: .normal)
        recordButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        recordButton.layer.cornerRadius = 25
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        
        // Pause button
        pauseButton.backgroundColor = UIColor(named: "WarningOrange")
        pauseButton.setTitleColor(.white, for: .normal)
        pauseButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        pauseButton.layer.cornerRadius = 20
        pauseButton.addTarget(self, action: #selector(pauseButtonTapped), for: .touchUpInside)
        pauseButton.isEnabled = false
        
        // Stop button
        stopButton.backgroundColor = UIColor(named: "ErrorRed")
        stopButton.setTitleColor(.white, for: .normal)
        stopButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        stopButton.layer.cornerRadius = 20
        stopButton.addTarget(self, action: #selector(stopButtonTapped), for: .touchUpInside)
        stopButton.isEnabled = false
        
        recordingStatusLabel.text = "Ready to record"
        recordingStatusLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        recordingStatusLabel.textColor = UIColor(named: "SecondaryText")
        recordingStatusLabel.textAlignment = .center
        
        recordingTimerLabel.text = "00:00"
        recordingTimerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 24, weight: .bold)
        recordingTimerLabel.textColor = UIColor(named: "PrimaryText")
        recordingTimerLabel.textAlignment = .center
    }
    
    private func setupWaveformVisualization() {
        waveformContainerView.backgroundColor = .white
        waveformContainerView.layer.cornerRadius = 12
        waveformContainerView.layer.shadowColor = UIColor.black.cgColor
        waveformContainerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        waveformContainerView.layer.shadowRadius = 4
        waveformContainerView.layer.shadowOpacity = 0.1
        
        waveformView.backgroundColor = UIColor(named: "BackgroundGray")
        waveformView.layer.cornerRadius = 8
        
        waveformScrollView.backgroundColor = .clear
        waveformScrollView.showsHorizontalScrollIndicator = false
        waveformScrollView.showsVerticalScrollIndicator = false
        
        waveformContentView.backgroundColor = .clear
        
        noAudioLabel.text = "No audio recorded yet"
        noAudioLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        noAudioLabel.textColor = UIColor(named: "SecondaryText")
        noAudioLabel.textAlignment = .center
        noAudioLabel.isHidden = false
        
        // Create waveform layer
        waveformLayer = CAShapeLayer()
        waveformLayer?.fillColor = UIColor(named: "PrimaryBlue")?.cgColor
        waveformLayer?.strokeColor = UIColor(named: "PrimaryBlue")?.cgColor
        waveformLayer?.lineWidth = 2
        waveformContentView.layer.addSublayer(waveformLayer!)
    }
    
    private func setupPlaybackControls() {
        playbackControlsContainerView.backgroundColor = .white
        playbackControlsContainerView.layer.cornerRadius = 12
        playbackControlsContainerView.layer.shadowColor = UIColor.black.cgColor
        playbackControlsContainerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        playbackControlsContainerView.layer.shadowRadius = 4
        playbackControlsContainerView.layer.shadowOpacity = 0.1
        playbackControlsContainerView.isHidden = true
        
        // Play button
        playButton.backgroundColor = UIColor(named: "PrimaryBlue")
        playButton.setTitleColor(.white, for: .normal)
        playButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        playButton.layer.cornerRadius = 20
        playButton.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        
        // Pause playback button
        pausePlaybackButton.backgroundColor = UIColor(named: "WarningOrange")
        pausePlaybackButton.setTitleColor(.white, for: .normal)
        pausePlaybackButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        pausePlaybackButton.layer.cornerRadius = 20
        pausePlaybackButton.addTarget(self, action: #selector(pausePlaybackButtonTapped), for: .touchUpInside)
        
        // Stop playback button
        stopPlaybackButton.backgroundColor = UIColor(named: "ErrorRed")
        stopPlaybackButton.setTitleColor(.white, for: .normal)
        stopPlaybackButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        stopPlaybackButton.layer.cornerRadius = 20
        stopPlaybackButton.addTarget(self, action: #selector(stopPlaybackButtonTapped), for: .touchUpInside)
        
        // Progress slider
        playbackProgressSlider.minimumValue = 0
        playbackProgressSlider.maximumValue = 1
        playbackProgressSlider.value = 0
        playbackProgressSlider.addTarget(self, action: #selector(progressSliderChanged), for: .valueChanged)
        
        playbackTimeLabel.text = "00:00"
        playbackTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        playbackTimeLabel.textColor = UIColor(named: "SecondaryText")
        
        totalTimeLabel.text = "00:00"
        totalTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        totalTimeLabel.textColor = UIColor(named: "SecondaryText")
    }
    
    private func setupSettings() {
        settingsContainerView.backgroundColor = .white
        settingsContainerView.layer.cornerRadius = 12
        settingsContainerView.layer.shadowColor = UIColor.black.cgColor
        settingsContainerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        settingsContainerView.layer.shadowRadius = 4
        settingsContainerView.layer.shadowOpacity = 0.1
        
        settingsTitleLabel.text = "Recording Settings"
        settingsTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        settingsTitleLabel.textColor = UIColor(named: "PrimaryText")
        
        qualitySegmentedControl.insertSegment(withTitle: "Low", at: 0, animated: false)
        qualitySegmentedControl.insertSegment(withTitle: "Medium", at: 1, animated: false)
        qualitySegmentedControl.insertSegment(withTitle: "High", at: 2, animated: false)
        qualitySegmentedControl.selectedSegmentIndex = 2 // High quality by default
        qualitySegmentedControl.addTarget(self, action: #selector(qualityChanged), for: .valueChanged)
        
        [sampleRateLabel, bitDepthLabel, formatLabel].forEach { label in
            label?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            label?.textColor = UIColor(named: "SecondaryText")
        }
    }
    
    private func setupRecordingsList() {
        recordingsContainerView.backgroundColor = .white
        recordingsContainerView.layer.cornerRadius = 12
        recordingsContainerView.layer.shadowColor = UIColor.black.cgColor
        recordingsContainerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        recordingsContainerView.layer.shadowRadius = 4
        recordingsContainerView.layer.shadowOpacity = 0.1
        
        recordingsTitleLabel.text = "Recent Recordings"
        recordingsTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        recordingsTitleLabel.textColor = UIColor(named: "PrimaryText")
        
        noRecordingsLabel.text = "No recordings yet"
        noRecordingsLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        noRecordingsLabel.textColor = UIColor(named: "SecondaryText")
        noRecordingsLabel.textAlignment = .center
        noRecordingsLabel.isHidden = true
    }
    
    private func setupLoadingOverlay() {
        loadingOverlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        loadingOverlayView.isHidden = true
        
        loadingLabel.text = "Processing audio..."
        loadingLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        loadingLabel.textColor = .white
        loadingLabel.textAlignment = .center
    }
    
    private func setupTableView() {
        recordingsTableView.delegate = self
        recordingsTableView.dataSource = self
        recordingsTableView.backgroundColor = .clear
        recordingsTableView.separatorStyle = .none
        recordingsTableView.showsVerticalScrollIndicator = false
        
        let recordingCellNib = UINib(nibName: "SiivRecordingCell", bundle: nil)
        recordingsTableView.register(recordingCellNib, forCellReuseIdentifier: "SiivRecordingCell")
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            showError("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    private func checkMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if !granted {
                    self?.showMicrophonePermissionAlert()
                }
            }
        }
    }
    
    private func showMicrophonePermissionAlert() {
        let alert = UIAlertController(
            title: "Microphone Access Required",
            message: "Please enable microphone access in Settings to record audio.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - Recording Controls
    @objc private func recordButtonTapped(_ sender: UIButton) {
        if isRecording {
            pauseRecording()
        } else {
            startRecording()
        }
    }
    
    @objc private func pauseButtonTapped(_ sender: UIButton) {
        if isPaused {
            resumeRecording()
        } else {
            pauseRecording()
        }
    }
    
    @objc private func stopButtonTapped(_ sender: UIButton) {
        stopRecording()
    }
    
    private func startRecording() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            showError("Failed to access documents directory")
            return
        }
        
        let recordingsPath = documentsPath.appendingPathComponent("Recordings")
        
        // Create recordings directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: recordingsPath.path) {
            do {
                try FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
            } catch {
                showError("Failed to create recordings directory")
                return
            }
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "recording_\(timestamp).m4a"
        recordingURL = recordingsPath.appendingPathComponent(fileName)
        
        guard let url = recordingURL else { return }
        
        let settings = getRecordingSettings()
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            if audioRecorder?.record() == true {
                isRecording = true
                isPaused = false
                recordingStartTime = Date()
                
                updateRecordingUI()
                startRecordingTimer()
                startWaveformUpdate()
                
                // Hide no audio label and show waveform
                noAudioLabel.isHidden = true
                waveformData.removeAll()
                updateWaveform()
            } else {
                showError("Failed to start recording")
            }
        } catch {
            showError("Failed to create audio recorder: \(error.localizedDescription)")
        }
    }
    
    private func pauseRecording() {
        audioRecorder?.pause()
        isPaused = true
        updateRecordingUI()
        stopRecordingTimer()
    }
    
    private func resumeRecording() {
        audioRecorder?.record()
        isPaused = false
        updateRecordingUI()
        startRecordingTimer()
        startWaveformUpdate()
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        isPaused = false
        recordingStartTime = nil
        
        updateRecordingUI()
        stopRecordingTimer()
        stopWaveformUpdate()
        
        if let url = recordingURL {
            processRecording(at: url)
        }
    }
    
    private func updateRecordingUI() {
        if isRecording {
            recordButton.setTitle("⏸", for: .normal)
            recordButton.backgroundColor = UIColor(named: "WarningOrange")
            pauseButton.isEnabled = true
            stopButton.isEnabled = true
            recordingStatusLabel.text = isPaused ? "Recording paused" : "Recording..."
            recordingStatusLabel.textColor = UIColor(named: "SuccessGreen")
        } else {
            recordButton.setTitle("●", for: .normal)
            recordButton.backgroundColor = UIColor(named: "SuccessGreen")
            pauseButton.isEnabled = false
            stopButton.isEnabled = false
            recordingStatusLabel.text = "Ready to record"
            recordingStatusLabel.textColor = UIColor(named: "SecondaryText")
        }
        
        saveButton.isEnabled = recordingURL != nil
    }
    
    // MARK: - Playback Controls
    @objc private func playButtonTapped(_ sender: UIButton) {
        startPlayback()
    }
    
    @objc private func pausePlaybackButtonTapped(_ sender: UIButton) {
        pausePlayback()
    }
    
    @objc private func stopPlaybackButtonTapped(_ sender: UIButton) {
        stopPlayback()
    }
    
    @objc private func progressSliderChanged(_ sender: UISlider) {
        guard let player = audioPlayer else { return }
        let newTime = Double(sender.value) * player.duration
        player.currentTime = newTime
        updatePlaybackTimeDisplay()
    }
    
    private func startPlayback() {
        guard let url = recordingURL else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            
            isPlaying = true
            updatePlaybackUI()
            startPlaybackTimer()
            
            playbackControlsContainerView.isHidden = false
            totalTimeLabel.text = formatTime(audioPlayer?.duration ?? 0)
        } catch {
            showError("Failed to start playback: \(error.localizedDescription)")
        }
    }
    
    private func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        updatePlaybackUI()
        stopPlaybackTimer()
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        updatePlaybackUI()
        stopPlaybackTimer()
        playbackProgressSlider.value = 0
        updatePlaybackTimeDisplay()
    }
    
    private func updatePlaybackUI() {
        if isPlaying {
            playButton.isEnabled = false
            pausePlaybackButton.isEnabled = true
            stopPlaybackButton.isEnabled = true
        } else {
            playButton.isEnabled = true
            pausePlaybackButton.isEnabled = false
            stopPlaybackButton.isEnabled = true
        }
    }
    
    // MARK: - Timers
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRecordingTimer()
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePlaybackProgress()
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func updateRecordingTimer() {
        guard let startTime = recordingStartTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        recordingTimerLabel.text = formatTime(elapsed)
    }
    
    private func updatePlaybackProgress() {
        guard let player = audioPlayer else { return }
        
        let progress = player.currentTime / player.duration
        playbackProgressSlider.value = Float(progress)
        updatePlaybackTimeDisplay()
    }
    
    private func updatePlaybackTimeDisplay() {
        guard let player = audioPlayer else { return }
        playbackTimeLabel.text = formatTime(player.currentTime)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Waveform Visualization
    private func setupWaveformView() {
        // Waveform view is already set up in setupWaveformVisualization()
    }
    
    private func startWaveformUpdate() {
        // Update waveform every 0.1 seconds during recording
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, self.isRecording && !self.isPaused else {
                timer.invalidate()
                return
            }
            self.updateWaveform()
        }
    }
    
    private func stopWaveformUpdate() {
        // Timer will automatically stop when isRecording becomes false
    }
    
    private func updateWaveform() {
        guard let recorder = audioRecorder else { return }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // Convert dB to amplitude (0-1)
        let amplitude = pow(10, averagePower / 20)
        waveformData.append(Float(amplitude))
        
        // Keep only last 1000 samples for performance
        if waveformData.count > 1000 {
            waveformData.removeFirst()
        }
        
        drawWaveform()
    }
    
    private func drawWaveform() {
        guard !waveformData.isEmpty else { return }
        
        let path = UIBezierPath()
        let width = waveformContentView.bounds.width
        let height = waveformContentView.bounds.height
        let centerY = height / 2
        
        // Calculate bar width based on number of samples
        let barWidth = max(2, width / CGFloat(waveformData.count))
        let spacing: CGFloat = 1
        
        for (index, amplitude) in waveformData.enumerated() {
            let x = CGFloat(index) * (barWidth + spacing)
            let barHeight = CGFloat(amplitude) * (height * 0.8)
            
            let rect = CGRect(
                x: x,
                y: centerY - barHeight / 2,
                width: barWidth,
                height: barHeight
            )
            
            path.append(UIBezierPath(roundedRect: rect, cornerRadius: barWidth / 2))
        }
        
        waveformLayer?.path = path.cgPath
        
        // Update content size for scrolling
        let contentWidth = CGFloat(waveformData.count) * (barWidth + spacing)
        waveformContentView.frame.size.width = max(width, contentWidth)
        waveformScrollView.contentSize = CGSize(width: contentWidth, height: height)
        
        // Scroll to end if recording
        if isRecording && !isPaused {
            let scrollX = max(0, contentWidth - width)
            waveformScrollView.setContentOffset(CGPoint(x: scrollX, y: 0), animated: true)
        }
    }
    
    // MARK: - Settings
    @objc private func qualityChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            audioQuality = .low
        case 1:
            audioQuality = .medium
        case 2:
            audioQuality = .high
        default:
            audioQuality = .high
        }
        
        updateSettingsDisplay()
    }
    
    private func updateSettingsDisplay() {
        switch audioQuality {
        case .low:
            sampleRate = 22050.0
            bitDepth = 16
            audioFormat = "AAC"
        case .medium:
            sampleRate = 44100.0
            bitDepth = 16
            audioFormat = "AAC"
        case .high:
            sampleRate = 48000.0
            bitDepth = 24
            audioFormat = "AAC"
        }
        
        sampleRateLabel.text = "Sample Rate: \(Int(sampleRate)) Hz"
        bitDepthLabel.text = "Bit Depth: \(bitDepth) bit"
        formatLabel.text = "Format: \(audioFormat)"
    }
    
    private func getRecordingSettings() -> [String: Any] {
        return [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: audioQuality.rawValue
        ]
    }
    
    // MARK: - Recording Processing
    private func processRecording(at url: URL) {
        showLoading(message: "Processing recording...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Get file attributes
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes?[.size] as? Int64 ?? 0
            
            // Create recording object
            let recording = Recording(
                id: UUID().uuidString,
                name: url.lastPathComponent.replacingOccurrences(of: ".m4a", with: ""),
                url: url,
                duration: self.audioPlayer?.duration ?? 0,
                fileSize: ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file),
                creationDate: Date(),
                waveformData: self.waveformData
            )
            
            DispatchQueue.main.async {
                self.hideLoading()
                self.recordings.insert(recording, at: 0)
                self.updateRecordingsUI()
                self.showPlaybackControls()
            }
        }
    }
    
    private func showPlaybackControls() {
        playbackControlsContainerView.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.playbackControlsContainerView.alpha = 1.0
        }
    }
    
    // MARK: - Recordings Management
    func loadRecordings() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let recordingsPath = documentsPath.appendingPathComponent("Recordings")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: recordingsPath, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [.skipsHiddenFiles])
            
            recordings = fileURLs.compactMap { url in
                let attributes = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                let fileSize = attributes?.fileSize ?? 0
                let creationDate = attributes?.creationDate ?? Date()
                
                return Recording(
                    id: url.lastPathComponent,
                    name: url.lastPathComponent.replacingOccurrences(of: ".m4a", with: ""),
                    url: url,
                    duration: 0, // Would need to load actual duration
                    fileSize: ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file),
                    creationDate: creationDate,
                    waveformData: []
                )
            }.sorted { $0.creationDate > $1.creationDate }
            
            updateRecordingsUI()
        } catch {
            print("Error loading recordings: \(error)")
        }
    }
    
    private func updateRecordingsUI() {
        noRecordingsLabel.isHidden = !recordings.isEmpty
        recordingsTableView.reloadData()
    }
    
    // MARK: - Loading State
    private func showLoading(message: String) {
        loadingLabel.text = message
        loadingOverlayView.isHidden = false
        loadingActivityIndicator.startAnimating()
    }
    
    private func hideLoading() {
        loadingOverlayView.isHidden = true
        loadingActivityIndicator.stopAnimating()
    }
    
    // MARK: - Actions
    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        stopRecording()
        stopPlayback()
        delegate?.audioRecorderDidCancel()
        dismiss(animated: true)
    }
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        guard let url = recordingURL else { return }
        
        showLoading(message: "Saving recording...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Here you would typically save to a more permanent location
            // or add to the app's audio library
            
            DispatchQueue.main.async {
                self.hideLoading()
                self.delegate?.audioRecorderDidFinish(url, name: url.lastPathComponent.replacingOccurrences(of: ".m4a", with: ""))
                self.dismiss(animated: true)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - AVAudioRecorderDelegate
extension SiivAudioRecorderViewController: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            showError("Recording failed")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            showError("Recording error: \(error.localizedDescription)")
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension SiivAudioRecorderViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        updatePlaybackUI()
        stopPlaybackTimer()
        playbackProgressSlider.value = 0
        updatePlaybackTimeDisplay()
    }
}

// MARK: - UITableViewDataSource
extension SiivAudioRecorderViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recordings.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SiivRecordingCell", for: indexPath) as! SiivRecordingCell
        let recording = recordings[indexPath.row]
        cell.configure(with: recording)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension SiivAudioRecorderViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let recording = recordings[indexPath.row]
        recordingURL = recording.url
        showPlaybackControls()
        
        // Load the recording for playback
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: recording.url)
            audioPlayer?.delegate = self
            totalTimeLabel.text = formatTime(audioPlayer?.duration ?? 0)
        } catch {
            showError("Failed to load recording: \(error.localizedDescription)")
        }
    }
}

// MARK: - Data Models
struct Recording {
    let id: String
    let name: String
    let url: URL
    let duration: TimeInterval
    let fileSize: String
    let creationDate: Date
    let waveformData: [Float]
}

enum AudioQuality: Int {
    case low = 0
    case medium = 1
    case high = 2
} 
