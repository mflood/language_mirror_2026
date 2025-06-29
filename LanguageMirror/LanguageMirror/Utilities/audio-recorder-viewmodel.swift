import Foundation
import AVFoundation
import Combine
import AVFAudio

/*

// MARK: - ViewModel State
enum RecordingState {
    case initial
    case recording
    case finishedRecording
    case previewing
}

// MARK: - ViewModel
class AudioRecorderViewModel: NSObject, ObservableObject  {
    // Published properties for UI binding
    @Published var recordingState: RecordingState = .initial
    @Published var recordingTitle: String = ""
    @Published var currentTime: TimeInterval = 0
    @Published var audioDuration: TimeInterval = 0
    @Published var isRecordingEnabled: Bool = false
    @Published var recordings: [AudioFile] = []
    @Published var errorMessage: String?
    
    // Services
    let audioService: AudioRecordingService
    let dataController: DataController
    
    // Private properties
    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?
    var timer: Timer?
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(dataController: DataController, audioService: AudioRecordingService = AudioRecordingServiceImpl()) {
        self.dataController = dataController
        self.audioService = audioService
        
        super.init()
        
        setupObservers()
        checkPermissions()
        generateNewRecordingTitle()
        loadRecordings()
    }
    
    deinit {
        stopTimer()
        cleanupAudioResources()
    }
    
    // MARK: - Public Methods
    func startRecording() {
        audioService.startRecording { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let recorder):
                self.audioRecorder = recorder
                self.recordingState = .recording
                self.startTimer()
            case .failure(let error):
                self.errorMessage = "Failed to start recording: \(error.localizedDescription)"
            }
        }
    }
    
    func stopRecording() {
        guard let recorder = audioRecorder else { return }
        
        recorder.stop()
        stopTimer()
        
        do {
            let player = try AVAudioPlayer(contentsOf: recorder.url)
            audioPlayer = player
            player.delegate = self
            player.prepareToPlay()
            
            audioDuration = player.duration
            currentTime = 0
            recordingState = .finishedRecording
        } catch {
            errorMessage = "Failed to prepare audio for playback: \(error.localizedDescription)"
            recordingState = .initial
        }
    }
    
    func startPlayback() {
        guard let player = audioPlayer else { return }
        
        player.currentTime = currentTime
        player.play()
        recordingState = .previewing
        startTimer()
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        stopTimer()
        recordingState = .finishedRecording
    }
    
    func seekTo(time: TimeInterval) {
        guard let player = audioPlayer else { return }
        
        let wasPlaying = recordingState == .previewing
        
        if wasPlaying {
            player.pause()
        }
        
        player.currentTime = time
        currentTime = time
        
        if wasPlaying {
            player.play()
        }
    }
    
    func saveRecording() {
        guard let url = audioRecorder?.url, !recordingTitle.isEmpty else {
            errorMessage = "Cannot save recording without a title"
            return
        }
        
        let sourceDescription = generateTimestamp()
        
        dataController.insertAudioUrl(
            name: recordingTitle,
            url: url,
            audioSourceType: .recorded,
            sourceDescription: sourceDescription
        )
        
        // Reset state and load new recordings
        recordingState = .initial
        loadRecordings()
        generateNewRecordingTitle()
    }
    
    func generateNewRecordingTitle() {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        recordingTitle = "Recording \(formatter.string(from: Date()))"
    }
    
    func loadRecordings() {
        recordings = dataController.selectAllAudioFiles(sourceType: .recorded, onlyFavorites: false, withSoundBites: false)
    }
    
    func deleteRecording(at index: Int) {
        guard index < recordings.count else { return }
        
        let audioFile = recordings[index]
        dataController.deleteAudio(audioFile)
        loadRecordings()
    }
    
    // MARK: - Private Methods
    private func setupObservers() {
        // Add observers for interruptions, route changes, etc.
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleAudioInterruption(notification: notification)
            }
            .store(in: &cancellables)
    }
    
    private func checkPermissions() {
        audioService.checkPermissions { [weak self] allowed in
            DispatchQueue.main.async {
                self?.isRecordingEnabled = allowed
                if !allowed {
                    self?.errorMessage = "Microphone access is required for recording"
                }
            }
        }
    }
    
    private func startTimer() {
        stopTimer()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            switch self.recordingState {
            case .recording:
                if let time = self.audioRecorder?.currentTime {
                    self.currentTime = time
                }
            case .previewing:
                if let time = self.audioPlayer?.currentTime {
                    self.currentTime = time
                }
            default:
                break
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func cleanupAudioResources() {
        audioRecorder?.stop()
        audioPlayer?.stop()
        audioRecorder = nil
        audioPlayer = nil
    }
    
    private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            if recordingState == .recording {
                stopRecording()
            } else if recordingState == .previewing {
                stopPlayback()
            }
        case .ended:
            // Optionally restart if appropriate
            break
        @unknown default:
            break
        }
    }
    
    private func generateTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: Date())
    }
}

// MARK: - AVAudioPlayerDelegate Extension

extension AudioRecorderViewModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopTimer()
        currentTime = 0
        recordingState = .finishedRecording
    }
}


// MARK: - Audio Recording Service Protocol
protocol AudioRecordingService {
    func checkPermissions(completion: @escaping (Bool) -> Void)
    func startRecording(completion: @escaping (Result<AVAudioRecorder, Error>) -> Void)
}

// MARK: - Audio Recording Service Implementation
class AudioRecordingServiceImpl: AudioRecordingService {
    enum AudioRecordingError: Error {
        case permissionDenied
        case setupFailed
        case recordingFailed
    }
    
    func checkPermissions(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { allowed in
            DispatchQueue.main.async {
                completion(allowed)
            }
        }
    }
    
    func startRecording(completion: @escaping (Result<AVAudioRecorder, Error>) -> Void) {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try audioSession.setActive(true)
            
            audioSession.requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    if allowed {
                        self.setupRecorder(completion: completion)
                    } else {
                        completion(.failure(AudioRecordingError.permissionDenied))
                    }
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    private func setupRecorder(completion: @escaping (Result<AVAudioRecorder, Error>) -> Void) {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("new_recording.m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            let recorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            recorder.isMeteringEnabled = true
            
            if recorder.record() {
                completion(.success(recorder))
            } else {
                completion(.failure(AudioRecordingError.recordingFailed))
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
*/
