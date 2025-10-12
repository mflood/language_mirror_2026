# iOS Practice App Implementation Design

## Overview
This document outlines the architecture and implementation plan for porting the web-based audio shadow practice app to iOS using UIKit (not SwiftUI). The design follows iOS best practices with proper separation of concerns, dependency injection, and clean architecture patterns.

## Core Architecture

### MVC Pattern with Services
- **Model**: Data structures and business logic
- **View**: UIKit views and view controllers
- **Controller**: View controllers coordinating between models and views
- **Services**: Audio management, file handling, and data persistence

## Object Interfaces & Protocols

### 1. Audio Management

#### `AudioPlayerProtocol`
```swift
protocol AudioPlayerProtocol: AnyObject {
    var delegate: AudioPlayerDelegate? { get set }
    var currentTime: TimeInterval { get set }
    var duration: TimeInterval { get }
    var playbackRate: Float { get set }
    var isPlaying: Bool { get }
    
    func loadAudio(from url: URL) async throws
    func play() async throws
    func pause()
    func stop()
    func seek(to time: TimeInterval) async throws
}

protocol AudioPlayerDelegate: AnyObject {
    func audioPlayerDidFinishPlaying(_ player: AudioPlayerProtocol)
    func audioPlayerTimeDidUpdate(_ player: AudioPlayerProtocol, currentTime: TimeInterval)
    func audioPlayerDidStartPlaying(_ player: AudioPlayerProtocol)
    func audioPlayerDidPause(_ player: AudioPlayerProtocol)
}
```

#### `AudioPlayerService`
```swift
class AudioPlayerService: AudioPlayerProtocol {
    private let avAudioPlayer: AVAudioPlayer
    private var timer: Timer?
    
    weak var delegate: AudioPlayerDelegate?
    
    // Implementation details...
}
```

### 2. File Management

#### `AudioFileManagerProtocol`
```swift
protocol AudioFileManagerProtocol {
    func getAudioFiles() async throws -> [AudioFile]
    func getAudioFileInfo(for url: URL) async throws -> AudioFileInfo
    func copyAudioFile(from sourceURL: URL, to destinationURL: URL) async throws
    func deleteAudioFile(at url: URL) async throws
}

struct AudioFile {
    let url: URL
    let filename: String
    let duration: TimeInterval?
    let fileSize: Int64
    let creationDate: Date
}

struct AudioFileInfo {
    let duration: TimeInterval
    let fileSize: Int64
    let format: String
    let bitRate: Int
}
```

#### `AudioFileManager`
```swift
class AudioFileManager: AudioFileManagerProtocol {
    private let documentsDirectory: URL
    private let audioFilesDirectory: URL
    
    init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        audioFilesDirectory = documentsDirectory.appendingPathComponent("AudioFiles")
        createAudioFilesDirectoryIfNeeded()
    }
    
    // Implementation details...
}
```

### 3. Practice Session Management

#### `PracticeSessionProtocol`
```swift
protocol PracticeSessionProtocol {
    var currentSection: PracticeSection? { get }
    var sections: [PracticeSection] { get }
    var globalSettings: GlobalSettings { get set }
    
    func createSection(at time: TimeInterval) async throws
    func deleteSection(_ section: PracticeSection) async throws
    func playSection(_ section: PracticeSection) async throws
    func stopCurrentSection()
    func proceedToNextSection() async throws
}

struct PracticeSection {
    let id: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let audioFileURL: URL
}

struct GlobalSettings {
    var playbackSpeed: Float
    var repeatCount: Int
}
```

#### `PracticeSessionManager`
```swift
class PracticeSessionManager: PracticeSessionProtocol {
    private let audioPlayer: AudioPlayerProtocol
    private let persistenceService: PersistenceServiceProtocol
    private var currentAudioFileURL: URL?
    
    weak var delegate: PracticeSessionDelegate?
    
    // Implementation details...
}

protocol PracticeSessionDelegate: AnyObject {
    func practiceSessionDidStartSection(_ session: PracticeSessionProtocol, section: PracticeSection)
    func practiceSessionDidCompleteSection(_ session: PracticeSessionProtocol, section: PracticeSection)
    func practiceSessionDidProceedToNextSection(_ session: PracticeSessionProtocol, nextSection: PracticeSection?)
    func practiceSessionDidCompleteAllSections(_ session: PracticeSessionProtocol)
}
```

### 4. Data Persistence

#### `PersistenceServiceProtocol`
```swift
protocol PersistenceServiceProtocol {
    func savePracticeSections(_ sections: [PracticeSection], for audioFileURL: URL) async throws
    func loadPracticeSections(for audioFileURL: URL) async throws -> [PracticeSection]
    func saveGlobalSettings(_ settings: GlobalSettings) async throws
    func loadGlobalSettings() async throws -> GlobalSettings
}
```

#### `PersistenceService`
```swift
class PersistenceService: PersistenceServiceProtocol {
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    
    // Implementation using JSON files or Core Data
}
```

## View Controllers

### 1. AudioFileListViewController

#### Responsibilities
- Display list of available audio files
- Handle file selection and navigation to practice view
- Manage file import/export functionality

#### Key Components
```swift
class AudioFileListViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var importButton: UIBarButtonItem!
    
    private let audioFileManager: AudioFileManagerProtocol
    private let viewModel: AudioFileListViewModel
    
    // Implementation details...
}
```

#### View Model
```swift
class AudioFileListViewModel {
    private let audioFileManager: AudioFileManagerProtocol
    
    var audioFiles: [AudioFile] = []
    var onAudioFileSelected: ((AudioFile) -> Void)?
    
    func loadAudioFiles() async {
        // Load and update audio files
    }
    
    func importAudioFile(from url: URL) async throws {
        // Handle file import
    }
}
```

### 2. PracticeViewController

#### Responsibilities
- Main practice interface
- Audio playback controls
- Section creation and management
- Global settings management

#### Key Components
```swift
class PracticeViewController: UIViewController {
    // MARK: - IBOutlets
    @IBOutlet weak var audioPlayerView: AudioPlayerView!
    @IBOutlet weak var sectionsTableView: UITableView!
    @IBOutlet weak var globalControlsView: GlobalControlsView!
    @IBOutlet weak var markPointButton: UIButton!
    
    // MARK: - Dependencies
    private let practiceSession: PracticeSessionProtocol
    private let audioFile: AudioFile
    private let viewModel: PracticeViewModel
    
    // MARK: - Properties
    private var isMarkingPoint = false
    private var currentPlayingSection: PracticeSection?
    
    // Implementation details...
}
```

#### Custom Views

##### `AudioPlayerView`
```swift
class AudioPlayerView: UIView {
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    weak var delegate: AudioPlayerViewDelegate?
    
    func updateProgress(currentTime: TimeInterval, duration: TimeInterval)
    func setPlaybackState(isPlaying: Bool)
}
```

##### `GlobalControlsView`
```swift
class GlobalControlsView: UIView {
    @IBOutlet weak var speedSegmentedControl: UISegmentedControl!
    @IBOutlet weak var repeatCountSlider: UISlider!
    @IBOutlet weak var repeatCountLabel: UILabel!
    
    weak var delegate: GlobalControlsViewDelegate?
    
    func updateSettings(_ settings: GlobalSettings)
}
```

##### `PracticeSectionCell`
```swift
class PracticeSectionCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var timeRangeLabel: UILabel!
    @IBOutlet weak var practiceButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    
    weak var delegate: PracticeSectionCellDelegate?
    
    func configure(with section: PracticeSection, isPlaying: Bool)
}
```

### 3. SettingsViewController

#### Responsibilities
- Global app settings
- Audio file management
- Export/import functionality

## Implementation Details

### 1. Audio Playback Implementation

#### Using AVAudioPlayer
```swift
class AudioPlayerService: AudioPlayerProtocol {
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    func loadAudio(from url: URL) async throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
    }
    
    func play() async throws {
        guard let player = audioPlayer else { throw AudioPlayerError.notLoaded }
        player.play()
        startTimer()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.delegate?.audioPlayerTimeDidUpdate(self, currentTime: player.currentTime)
        }
    }
}
```

### 2. Section Playback Logic

#### Practice Session Implementation
```swift
extension PracticeSessionManager {
    func playSection(_ section: PracticeSection) async throws {
        currentSection = section
        delegate?.practiceSessionDidStartSection(self, section: section)
        
        let settings = globalSettings
        var currentRepeat = 0
        
        while currentRepeat < settings.repeatCount {
            try await playSectionOnce(section)
            currentRepeat += 1
            
            if currentRepeat < settings.repeatCount {
                // Brief pause between repeats
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        
        delegate?.practiceSessionDidCompleteSection(self, section: section)
        try await proceedToNextSection()
    }
    
    private func playSectionOnce(_ section: PracticeSection) async throws {
        try await audioPlayer.seek(to: section.startTime)
        try await audioPlayer.play()
        
        // Wait for section to complete
        while audioPlayer.currentTime < section.endTime && audioPlayer.isPlaying {
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        audioPlayer.pause()
    }
}
```

### 3. Data Persistence

#### JSON-based Storage
```swift
extension PersistenceService {
    func savePracticeSections(_ sections: [PracticeSection], for audioFileURL: URL) async throws {
        let fileName = audioFileURL.lastPathComponent
        let sectionsURL = documentsDirectory
            .appendingPathComponent("PracticeSections")
            .appendingPathComponent("\(fileName).json")
        
        let data = try JSONEncoder().encode(sections)
        try data.write(to: sectionsURL)
    }
    
    func loadPracticeSections(for audioFileURL: URL) async throws -> [PracticeSection] {
        let fileName = audioFileURL.lastPathComponent
        let sectionsURL = documentsDirectory
            .appendingPathComponent("PracticeSections")
            .appendingPathComponent("\(fileName).json")
        
        let data = try Data(contentsOf: sectionsURL)
        return try JSONDecoder().decode([PracticeSection].self, from: data)
    }
}
```

### 4. UI State Management

#### Practice View Controller State
```swift
extension PracticeViewController {
    private func updateUI() {
        updateAudioPlayerView()
        updateSectionsTableView()
        updateGlobalControlsView()
        updateMarkPointButton()
    }
    
    private func updateMarkPointButton() {
        let title = isMarkingPoint ? "📍 Marking Point..." : "📍 Mark Practice Point"
        markPointButton.setTitle(title, for: .normal)
        markPointButton.isEnabled = !isMarkingPoint
    }
    
    private func updateSectionsTableView() {
        sectionsTableView.reloadData()
        
        // Highlight currently playing section
        if let currentSection = currentPlayingSection,
           let index = practiceSession.sections.firstIndex(where: { $0.id == currentSection.id }) {
            let indexPath = IndexPath(row: index, section: 0)
            sectionsTableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
        }
    }
}
```

## Error Handling

### Custom Error Types
```swift
enum AudioPlayerError: Error {
    case notLoaded
    case playbackFailed
    case seekFailed
}

enum PracticeSessionError: Error {
    case sectionNotFound
    case invalidTimeRange
    case audioFileNotFound
}

enum FileManagerError: Error {
    case fileNotFound
    case permissionDenied
    case invalidFileFormat
}
```

### Error Handling in View Controllers
```swift
extension PracticeViewController {
    private func handleError(_ error: Error) {
        let alert = UIAlertController(
            title: "Oops! Something went wrong",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Try Again", style: .default))
        present(alert, animated: true)
    }
}
```

## Testing Strategy

### Unit Tests
- Audio player service tests
- Practice session manager tests
- File manager tests
- Persistence service tests

### Integration Tests
- End-to-end practice session flow
- File import/export functionality
- UI state synchronization

### UI Tests
- Practice section creation
- Audio playback controls
- Settings management

## Performance Considerations

### Memory Management
- Proper cleanup of audio players
- Efficient table view cell reuse
- Background task handling for file operations

### Audio Performance
- Preloading audio files
- Efficient seeking and playback
- Background audio session management

### UI Responsiveness
- Async/await for all file operations
- Main thread updates for UI changes
- Progress indicators for long operations

This architecture provides a clean, testable, and maintainable foundation for the iOS practice app while maintaining the same functionality as the web version.
