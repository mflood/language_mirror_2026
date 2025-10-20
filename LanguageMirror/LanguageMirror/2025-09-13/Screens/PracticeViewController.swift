//
//  PracticeViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

// path: Screens/PracticeViewController.swift
import UIKit

protocol PracticeViewControllerDelegate: AnyObject {
    func practiceViewController(_ vc: PracticeViewController, didTapTrackTitle track: Track)
}

final class PracticeViewController: UIViewController {

    private let settings: SettingsService
    private let library: LibraryService
    private let clipService: ClipService
    private let player: AudioPlayerService
    private let practiceService: PracticeService
    
    weak var delegate: PracticeViewControllerDelegate?

    // Data
    private var selectedTrack: Track? {
        didSet {
            // Stop playback when switching to a different track to avoid edge cases
            if let oldTrack = oldValue, let newTrack = selectedTrack, oldTrack.id != newTrack.id {
                stopCurrentPlayback()
            }
            
            if let t = selectedTrack {
                UserDefaults.standard.set(t.id, forKey: "practice.lastTrackId")
            }
            refreshDataAsync()
        }
    }
    private var selectedPracticeSetId: String?  // Specific practice set to load
    private var practiceSet: PracticeSet?  // Original loaded practice set
    private var workingClips: [Clip] = []  // In-memory mutable copy for editing
    private var allClips: [Clip] = []  // All clips in practice set (deprecated, use workingClips)
    private var currentSession: PracticeSession?
    private var hasUnsavedChanges: Bool = false {
        didSet {
            updateSaveDiscardButtons()
        }
    }
    
    // UI Components
    private let headerView = UIView()
    private let trackButton = UIButton(type: .system)
    private let foreverButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let discardButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let bottomBar = UIView()
    private let playPauseButton = UIButton(type: .system)
    private let splitButton = UIButton(type: .system)
    private let mergeButton = UIButton(type: .system)
    private let progressLabel = UILabel()
    private let emptyStateView = EmptyStateView()
    
    // State
    private var isPlaying = false
    private var isPaused = false
    private var currentTrackTimeMs: Int?
    private var currentClipStartMs: Int?
    private var currentClipEndMs: Int?

    init(settings: SettingsService,
         libraryService: LibraryService,
         clipService: ClipService,
         audioPlayer: AudioPlayerService,
         practiceService: PracticeService) {
        self.settings = settings
        self.library = libraryService
        self.clipService = clipService
        self.player = audioPlayer
        self.practiceService = practiceService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = AppColors.calmBackground

        setupUI()
        setupNotifications()
        restoreLastTrackOrPickFirst()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Hide navigation bar since we use a custom headerView
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Show navigation bar when leaving this screen
        navigationController?.setNavigationBarHidden(false, animated: animated)
        
        // Stop playback when navigating away from Practice screen
        // This prevents edge cases where audio continues playing for a different track
        if isMovingFromParent || isBeingDismissed {
            stopCurrentPlayback()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopCurrentPlayback()
    }

    // MARK: - Setup

    private func setupUI() {
        // Header
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = AppColors.primaryBackground
        view.addSubview(headerView)
        
        // Track button
        trackButton.translatesAutoresizingMaskIntoConstraints = false
        trackButton.setTitle("Select Track ▼", for: .normal)
        trackButton.setTitleColor(AppColors.primaryText, for: .normal)
        trackButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        trackButton.addTarget(self, action: #selector(trackButtonTapped), for: .touchUpInside)
        headerView.addSubview(trackButton)
        
        // Forever button (infinity symbol)
        foreverButton.translatesAutoresizingMaskIntoConstraints = false
        foreverButton.setTitle("∞", for: .normal)
        foreverButton.setTitleColor(AppColors.secondaryText, for: .normal)
        foreverButton.titleLabel?.font = .systemFont(ofSize: 24, weight: .bold)
        foreverButton.addTarget(self, action: #selector(foreverButtonTapped), for: .touchUpInside)
        headerView.addSubview(foreverButton)
        
        // Save button
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle("Save", for: .normal)
        saveButton.setTitleColor(AppColors.primaryAccent, for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        saveButton.alpha = 0
        saveButton.isHidden = true
        headerView.addSubview(saveButton)
        
        // Discard button
        discardButton.translatesAutoresizingMaskIntoConstraints = false
        discardButton.setTitle("Discard", for: .normal)
        discardButton.setTitleColor(.systemRed, for: .normal)
        discardButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        discardButton.addTarget(self, action: #selector(discardButtonTapped), for: .touchUpInside)
        discardButton.alpha = 0
        discardButton.isHidden = true
        headerView.addSubview(discardButton)
        
        // Settings button (gear)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
        settingsButton.tintColor = AppColors.primaryAccent
        settingsButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
        headerView.addSubview(settingsButton)
        
        // Table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ClipCell.self, forCellReuseIdentifier: "ClipCell")
        view.addSubview(tableView)
        
        // Empty state
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        view.addSubview(emptyStateView)
        
        // Bottom bar
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.backgroundColor = AppColors.cardBackground
        bottomBar.layer.shadowColor = UIColor.black.cgColor
        bottomBar.layer.shadowOpacity = 0.1
        bottomBar.layer.shadowOffset = CGSize(width: 0, height: -2)
        bottomBar.layer.shadowRadius = 8
        view.addSubview(bottomBar)
        
        // Play/Pause button
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        let playConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        playPauseButton.setImage(UIImage(systemName: "play.circle.fill", withConfiguration: playConfig), for: .normal)
        playPauseButton.tintColor = AppColors.primaryAccent
        playPauseButton.addTarget(self, action: #selector(playPauseButtonTapped), for: .touchUpInside)
        bottomBar.addSubview(playPauseButton)
        
        // Split button
        splitButton.translatesAutoresizingMaskIntoConstraints = false
        let splitConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        splitButton.setImage(UIImage(systemName: "scissors", withConfiguration: splitConfig), for: .normal)
        splitButton.tintColor = AppColors.tertiaryText
        splitButton.isEnabled = false
        splitButton.alpha = 0.4
        splitButton.addTarget(self, action: #selector(splitButtonTapped), for: .touchUpInside)
        bottomBar.addSubview(splitButton)
        
        // Merge button
        mergeButton.translatesAutoresizingMaskIntoConstraints = false
        let mergeConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        mergeButton.setImage(UIImage(systemName: "arrow.up.square.fill", withConfiguration: mergeConfig), for: .normal)
        mergeButton.tintColor = AppColors.tertiaryText
        mergeButton.isEnabled = false
        mergeButton.alpha = 0.4
        mergeButton.addTarget(self, action: #selector(mergeButtonTapped), for: .touchUpInside)
        bottomBar.addSubview(mergeButton)
        
        // Progress label (status display)
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        progressLabel.textColor = AppColors.secondaryText
        progressLabel.text = "Ready to practice"
        progressLabel.textAlignment = .left
        progressLabel.numberOfLines = 2
        bottomBar.addSubview(progressLabel)
        
        // Layout
        NSLayoutConstraint.activate([
            // Header
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 56),
            
            trackButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            trackButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            trackButton.trailingAnchor.constraint(lessThanOrEqualTo: foreverButton.leadingAnchor, constant: -12),
            
            settingsButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            settingsButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 44),
            
            discardButton.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -8),
            discardButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            saveButton.trailingAnchor.constraint(equalTo: discardButton.leadingAnchor, constant: -8),
            saveButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            foreverButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -8),
            foreverButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            foreverButton.widthAnchor.constraint(equalToConstant: 44),
            foreverButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Bottom bar
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 92),
            
            // Control buttons (top section of bottom bar)
            playPauseButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            playPauseButton.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 8),
            playPauseButton.widthAnchor.constraint(equalToConstant: 44),
            playPauseButton.heightAnchor.constraint(equalToConstant: 44),
            
            splitButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 12),
            splitButton.topAnchor.constraint(equalTo: playPauseButton.topAnchor),
            splitButton.widthAnchor.constraint(equalToConstant: 44),
            splitButton.heightAnchor.constraint(equalToConstant: 44),
            
            mergeButton.leadingAnchor.constraint(equalTo: splitButton.trailingAnchor, constant: 12),
            mergeButton.topAnchor.constraint(equalTo: playPauseButton.topAnchor),
            mergeButton.widthAnchor.constraint(equalToConstant: 44),
            mergeButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Status display (bottom section of bottom bar)
            progressLabel.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            progressLabel.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
            progressLabel.topAnchor.constraint(equalTo: playPauseButton.bottomAnchor, constant: 4),
            progressLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomBar.bottomAnchor, constant: -8),
            
            // Table view
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            
            // Empty state
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
        ])
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handlePlaybackStopped), name: .AudioPlayerDidStop, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePlaybackStarted), name: .AudioPlayerDidStart, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleClipDidChange(_:)), name: .AudioPlayerClipDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleLoopDidComplete(_:)), name: .AudioPlayerLoopDidComplete, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSpeedDidChange(_:)), name: .AudioPlayerSpeedDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTimeUpdate(_:)), name: .AudioPlayerDidUpdateTime, object: nil)
    }

    private func restoreLastTrackOrPickFirst() {
        if let lastId = UserDefaults.standard.string(forKey: "practice.lastTrackId"),
           let t = try? library.loadTrack(id: lastId) {
            selectedTrack = t
            return
        }
        // fallback: first track if exists
        if let first = library.listTracks(in: nil).first {
            selectedTrack = first
        }
    }

    private func refreshDataAsync() {
        guard let t = selectedTrack else {
            allClips = []
            workingClips = []
            practiceSet = nil
            currentSession = nil
            hasUnsavedChanges = false
            updateUI()
            return
        }

        trackButton.setTitle(t.title, for: .normal)
        
        let packId = t.packId
        let trackId = t.id
        let practiceSetId = self.selectedPracticeSetId

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            
            // Load practice set from track's practice sets array
            let finalSet: PracticeSet
            if let setId = practiceSetId, let foundSet = t.practiceSets.first(where: { $0.id == setId }) {
                finalSet = foundSet
            } else if let firstSet = t.practiceSets.first {
                // No specific ID requested, use first practice set
                finalSet = firstSet
            } else {
                // No practice sets exist, create a default one
                finalSet = PracticeSet.fullTrackFactory(trackId: trackId, displayOrder: 0, trackDurationMs: t.durationMs)
            }
            
            let session = try? self.practiceService.loadSession(packId: packId, trackId: trackId)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.selectedTrack?.id == trackId else { return }
                
                self.practiceSet = finalSet
                self.workingClips = finalSet.clips  // Initialize working copy from saved practice set
                self.allClips = finalSet.clips  // Keep for backward compatibility
                self.currentSession = session
                self.hasUnsavedChanges = false
                self.updateUI()
            }
        }
    }
    
    private func updateUI() {
        let hasClips = !workingClips.isEmpty
        tableView.isHidden = !hasClips
        emptyStateView.isHidden = hasClips
        
        if hasClips {
            tableView.reloadData()
            // Delay scroll to ensure table view has processed the reload
            DispatchQueue.main.async { [weak self] in
                self?.scrollToCurrentClipIfNeeded()
            }
        } else {
            emptyStateView.configure(
                icon: "waveform.slash",
                title: "No Practice Clips",
                message: "This track doesn't have any clips yet",
                actionTitle: nil
            )
        }
        
        updateForeverButton()
        updateProgressLabel()
        validateMergeButton()
    }
    
    private func updateForeverButton() {
        let isForever = currentSession?.foreverMode ?? false
        foreverButton.setTitleColor(isForever ? AppColors.primaryAccent : AppColors.secondaryText, for: .normal)
    }
    
    private func updateProgressLabel() {
        guard let session = currentSession, !workingClips.isEmpty else {
            progressLabel.text = "Ready to practice"
            return
        }
        
        let clipIndex = min(session.currentClipIndex, workingClips.count - 1)
        let totalLoops = settings.globalRepeats
        
        // Format time displays
        var text = ""
        
        // Add clip time if available
        if let trackMs = currentTrackTimeMs, let startMs = currentClipStartMs, let endMs = currentClipEndMs {
            let clipElapsed = max(0, trackMs - startMs)
            let clipDuration = max(0, endMs - startMs)
            text += "Clip: \(formatTime(clipElapsed))/\(formatTime(clipDuration)) • "
        }
        
        // Add track time if available
        if let trackMs = currentTrackTimeMs, let track = selectedTrack, let durationMs = track.durationMs {
            text += "Track: \(formatTime(trackMs))/\(formatTime(durationMs))\n"
        } else {
            text += "\n"
        }
        
        text += "Clip \(clipIndex + 1)/\(workingClips.count) • Loop \(session.currentLoopCount)/\(totalLoops) • \(String(format: "%.2fx", session.currentSpeed))"
        
        progressLabel.text = text
    }
    
    private func formatTime(_ ms: Int) -> String {
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func validateSplitButton() {
        guard isPlaying,
              let trackMs = currentTrackTimeMs,
              let startMs = currentClipStartMs,
              let endMs = currentClipEndMs,
              trackMs > startMs + 500,
              trackMs < endMs - 500 else {
            splitButton.isEnabled = false
            splitButton.tintColor = AppColors.tertiaryText
            splitButton.alpha = 0.4
            return
        }
        
        splitButton.isEnabled = true
        splitButton.tintColor = AppColors.primaryAccent
        splitButton.alpha = 1.0
    }
    
    private func validateMergeButton() {
        guard let session = currentSession,
              session.currentClipIndex > 0,
              workingClips.count > 1 else {
            mergeButton.isEnabled = false
            mergeButton.tintColor = AppColors.tertiaryText
            mergeButton.alpha = 0.4
            return
        }
        
        mergeButton.isEnabled = true
        mergeButton.tintColor = AppColors.primaryAccent
        mergeButton.alpha = 1.0
    }
    
    private func scrollToCurrentClipIfNeeded() {
        guard let session = currentSession,
              !workingClips.isEmpty,
              session.currentClipIndex < workingClips.count,
              tableView.numberOfRows(inSection: 0) > 0,
              session.currentClipIndex < tableView.numberOfRows(inSection: 0) else { 
            print("  ⚠️ [PracticeViewController] Cannot scroll - session: \(currentSession != nil), clips: \(workingClips.count), tableRows: \(tableView.numberOfRows(inSection: 0))")
            return 
        }
        
        let indexPath = IndexPath(row: session.currentClipIndex, section: 0)
        tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
    }
    
    // MARK: - Actions
    
    @objc private func trackButtonTapped() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // If we have a selected track, navigate to its details in Library
        if let track = selectedTrack {
            delegate?.practiceViewController(self, didTapTrackTitle: track)
        } else {
            // Otherwise, show track picker
            let picker = PracticeTrackPickerViewController(libraryService: library)
            picker.onPick = { [weak self] t in
                self?.selectedTrack = t
            }
            navigationController?.pushViewController(picker, animated: true)
        }
    }
    
    @objc private func foreverButtonTapped() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        guard var session = currentSession else {
            // Create new session with forever mode enabled
            guard let track = selectedTrack,
                  let set = practiceSet else { return }
            
            do {
                var newSession = try practiceService.createSession(practiceSet: set, packId: track.packId, trackId: track.id)
                newSession.foreverMode = true
                try practiceService.saveSession(newSession)
                currentSession = newSession
                updateForeverButton()
            } catch {
                print("Failed to create session: \(error)")
            }
            return
        }
        
        // Toggle forever mode on existing session
        session.foreverMode.toggle()
        do {
            try practiceService.saveSession(session)
            currentSession = session
            updateForeverButton()
        } catch {
            print("Failed to save session: \(error)")
        }
    }
    
    @objc private func settingsButtonTapped() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let settingsVC = PracticeSettingsViewController(settings: settings)
        let nav = UINavigationController(rootViewController: settingsVC)
        present(nav, animated: true)
    }
    
    @objc private func saveButtonTapped() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        guard let track = selectedTrack, let practiceSet = practiceSet else { return }
        
        // Create alert for save options
        let alert = UIAlertController(title: "Save Practice Set", message: "Choose how to save your changes", preferredStyle: .alert)
        
        // Add text field for name
        alert.addTextField { textField in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            textField.placeholder = "Sliced Track \(formatter.string(from: Date()))"
            textField.autocapitalizationType = .words
        }
        
        // Save as New action
        alert.addAction(UIAlertAction(title: "Save as New", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            let textField = alert.textFields?.first
            let name = textField?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let finalName = name.isEmpty ? textField?.placeholder ?? "Practice Set" : name
            
            self.saveAsNewPracticeSet(name: finalName, for: track)
        })
        
        // Update Current action (only if not the default practice set)
        if !practiceSet.clips.isEmpty && practiceSet.title != nil {
            alert.addAction(UIAlertAction(title: "Update Current", style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.updateCurrentPracticeSet(for: track)
            })
        }
        
        // Cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    @objc private func discardButtonTapped() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Discard Changes?",
            message: "All unsaved changes will be lost.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.discardChanges()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func updateSaveDiscardButtons() {
        let shouldShow = hasUnsavedChanges
        
        // When showing buttons, unhide them BEFORE animating alpha
        // (hidden views don't render, so alpha animation has no effect)
        if shouldShow {
            saveButton.isHidden = false
            discardButton.isHidden = false
        }
        
        UIView.animate(withDuration: 0.3) {
            self.saveButton.alpha = shouldShow ? 1.0 : 0.0
            self.discardButton.alpha = shouldShow ? 1.0 : 0.0
        } completion: { _ in
            // When hiding buttons, set isHidden AFTER animation completes
            if !shouldShow {
                self.saveButton.isHidden = true
                self.discardButton.isHidden = true
            }
        }
    }
    
    private func saveAsNewPracticeSet(name: String, for track: Track) {
        guard let practiceSet = practiceSet else { return }
        
        // Create new practice set with working clips
        let newPracticeSet = PracticeSet(
            id: UUID().uuidString,
            trackId: track.id,
            displayOrder: track.practiceSets.count,
            title: name,
            clips: workingClips
        )
        
        do {
            // Add to library
            try library.addPracticeSet(newPracticeSet, to: track.id)
            
            // Reload track to get updated practice sets
            let updatedTrack = try library.loadTrack(id: track.id)
            selectedTrack = updatedTrack
            
            // Create new session for the new practice set
            // (practiceSetId is immutable, so we need a new session)
            let newSession = try practiceService.createSession(
                practiceSet: newPracticeSet,
                packId: track.packId,
                trackId: track.id
            )
            try practiceService.saveSession(newSession)
            currentSession = newSession
            
            // Load the new practice set
            selectedPracticeSetId = newPracticeSet.id
            refreshDataAsync()
            
            // Success feedback
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)
            
            presentAlert("Saved", "Practice set '\(name)' created successfully")
        } catch {
            presentAlert("Save Failed", error.localizedDescription)
        }
    }
    
    private func updateCurrentPracticeSet(for track: Track) {
        guard var practiceSet = practiceSet else { return }
        
        // Update practice set with working clips
        practiceSet.clips = workingClips
        
        do {
            // Update in library
            try library.updatePracticeSet(practiceSet, in: track.id)
            
            // Reload track
            let updatedTrack = try library.loadTrack(id: track.id)
            selectedTrack = updatedTrack
            
            // Reload the practice set
            refreshDataAsync()
            
            // Success feedback
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)
            
            presentAlert("Updated", "Practice set updated successfully")
        } catch {
            presentAlert("Update Failed", error.localizedDescription)
        }
    }
    
    private func discardChanges() {
        guard let practiceSet = practiceSet else { return }
        
        // Reset working clips to saved state
        workingClips = practiceSet.clips
        hasUnsavedChanges = false
        
        // Reload table view
        tableView.reloadData()
        
        // Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    @objc private func playPauseButtonTapped() {
        if isPlaying && !isPaused {
            // Pause
            player.pause()
            isPaused = true
            isPlaying = false
            updatePlayPauseButton()
        } else if isPaused {
            // Resume
            player.resume()
            isPaused = false
            isPlaying = true
            updatePlayPauseButton()
        } else {
            // Start new playback
            startPractice()
        }
    }
    
    private func startPractice() {
        guard let track = selectedTrack, let set = practiceSet, !workingClips.isEmpty else {
            print("⚠️ [PracticeViewController] startPractice: guard failed - track=\(selectedTrack != nil), set=\(practiceSet != nil), workingClips.isEmpty=\(workingClips.isEmpty)")
            return
        }
        
        print("▶️ [PracticeViewController] startPractice called:")
        print("  Track: \(track.title) (filename: \(track.filename))")
        print("  All working clips count: \(workingClips.count)")
        
        // Filter to only play drill clips
        let drillClips = workingClips.filter { $0.kind == .drill }
        print("  Drill clips count after filter: \(drillClips.count)")
        
        guard !drillClips.isEmpty else {
            print("⚠️ [PracticeViewController] No drill clips found")
            presentAlert("No Drills", "This track has no drill clips to practice")
            return
        }
        
        // Validate clip times
        let invalidClips = drillClips.filter { $0.startMs < 0 || $0.endMs <= $0.startMs }
        guard invalidClips.isEmpty else {
            print("❌ [PracticeViewController] Invalid clips found: \(invalidClips.count)")
            for clip in invalidClips {
                print("  Invalid clip: startMs=\(clip.startMs), endMs=\(clip.endMs)")
            }
            presentAlert("Invalid Clips", "Some drill clips have invalid time ranges. Please edit segments.")
            return
        }
        
        print("  Playback settings:")
        print("    globalRepeats: \(settings.globalRepeats)")
        print("    gapSeconds: \(settings.gapSeconds)")
        print("    interSegmentGapSeconds: \(settings.interSegmentGapSeconds)")
        print("    prerollMs: \(settings.prerollMs)")
        
        do {
            // Create or load session
            var session: PracticeSession?
            if let existing = currentSession {
                session = existing
                print("  Using existing session: \(existing.id)")
                
                // Convert session's currentClipIndex (which is in workingClips) to drillClips index
                if existing.currentClipIndex < workingClips.count {
                    let currentClip = workingClips[existing.currentClipIndex]
                    if let drillIndex = drillClips.firstIndex(where: { $0.id == currentClip.id }) {
                        session?.currentClipIndex = drillIndex
                        print("  Converted workingClips index \(existing.currentClipIndex) to drillClips index \(drillIndex)")
                    } else {
                        // Current clip is not a drill, start from first drill
                        session?.currentClipIndex = 0
                        print("  Current clip is not a drill, starting from first drill")
                    }
                } else {
                    session?.currentClipIndex = 0
                }
            } else {
                session = try practiceService.createSession(practiceSet: set, packId: track.packId, trackId: track.id)
                session?.currentClipIndex = 0
                currentSession = session
                print("  Created new session: \(session?.id ?? "nil")")
            }
            
            print("  Calling player.play() with \(drillClips.count) drill clips...")
            
            // Start playback with session (only drill clips are played)
            if let playerWithSession = player as? AudioPlayerServiceAVPlayer {
                try playerWithSession.play(
                    track: track,
                    clips: drillClips,
                    globalRepeats: settings.globalRepeats,
                    gapSeconds: settings.gapSeconds,
                    interClipGapSeconds: settings.interSegmentGapSeconds,
                    prerollMs: settings.prerollMs,
                    session: session
                )
            } else {
                try player.play(
                    track: track,
                    clips: drillClips,
                    globalRepeats: settings.globalRepeats,
                    gapSeconds: settings.gapSeconds,
                    interClipGapSeconds: settings.interSegmentGapSeconds,
                    prerollMs: settings.prerollMs
                )
            }
            
            print("✅ [PracticeViewController] Playback started successfully")
            
            isPlaying = true
            isPaused = false
            updatePlayPauseButton()
        } catch {
            print("❌ [PracticeViewController] Playback error: \(error.localizedDescription)")
            presentAlert("Playback Error", error.localizedDescription)
        }
    }
    
    private func updatePlayPauseButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let imageName = (isPlaying && !isPaused) ? "pause.circle.fill" : "play.circle.fill"
        playPauseButton.setImage(UIImage(systemName: imageName, withConfiguration: config), for: .normal)
    }
    
    // MARK: - Notifications
    
    @objc private func handlePlaybackStopped() {
        isPaused = false
        isPlaying = false
        updatePlayPauseButton()
        tableView.reloadData()
    }
    
    @objc private func handlePlaybackStarted() {
        isPaused = false
        isPlaying = true
        updatePlayPauseButton()
    }
    
    @objc private func handleClipDidChange(_ notification: Notification) {
        // IMPORTANT: Index Management Strategy
        // - Table view displays ALL clips (drill, skip, noise) from workingClips array
        // - Audio player only receives/plays drill clips (filtered array)
        // - Player tracks indices in the filtered drill clips array
        // - Session needs to track indices in the full workingClips array for UI consistency
        // - Solution: Use clipId from notification to find actual index in workingClips
        
        guard let clipId = notification.userInfo?["clipId"] as? String else { return }
        
        // Find the index of this clip in the full workingClips array
        guard let actualIndex = workingClips.firstIndex(where: { $0.id == clipId }) else {
            print("⚠️ [PracticeViewController] Could not find clip with ID: \(clipId)")
            return
        }
        
        // Update session to reflect actual index in workingClips
        if var session = currentSession {
            session.currentClipIndex = actualIndex
            do {
                try practiceService.saveSession(session)
                currentSession = session
            } catch {
                print("⚠️ [PracticeViewController] Failed to update session: \(error)")
            }
        }
        
        // Reload cells to update visual state
        tableView.reloadData()
        
        // Scroll to current clip using actual index
        let indexPath = IndexPath(row: actualIndex, section: 0)
        tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        
        updateProgressLabel()
        validateMergeButton()
    }
    
    @objc private func handleLoopDidComplete(_ notification: Notification) {
        // Reload current cell to update progress
        if let session = currentSession, session.currentClipIndex < workingClips.count {
            let indexPath = IndexPath(row: session.currentClipIndex, section: 0)
            tableView.reloadRows(at: [indexPath], with: .none)
        }
        
        updateProgressLabel()
    }
    
    @objc private func handleSpeedDidChange(_ notification: Notification) {
        updateProgressLabel()
    }
    
    @objc private func handleTimeUpdate(_ notification: Notification) {
        guard let trackTimeMs = notification.userInfo?["trackTimeMs"] as? Int,
              let clipStartMs = notification.userInfo?["clipStartMs"] as? Int,
              let clipEndMs = notification.userInfo?["clipEndMs"] as? Int else { return }
        
        currentTrackTimeMs = trackTimeMs
        currentClipStartMs = clipStartMs
        currentClipEndMs = clipEndMs
        
        updateProgressLabel()
        validateSplitButton()
    }
    
    @objc private func splitButtonTapped() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        guard let trackMs = currentTrackTimeMs,
              let session = currentSession,
              session.currentClipIndex < workingClips.count else { return }
        
        let clip = workingClips[session.currentClipIndex]
        
        // Validate split point
        guard trackMs > clip.startMs + 500,
              trackMs < clip.endMs - 500 else {
            presentAlert("Invalid Split", "Split point must be at least 0.5 seconds from clip boundaries")
            return
        }
        
        // Split the clip in memory
        let clip1 = Clip(
            id: clip.id,
            startMs: clip.startMs,
            endMs: trackMs,
            kind: clip.kind,
            title: clip.title,
            repeats: clip.repeats,
            startSpeed: clip.startSpeed,
            endSpeed: clip.endSpeed,
            languageCode: clip.languageCode
        )
        
        let clip2 = Clip(
            id: UUID().uuidString,
            startMs: trackMs,
            endMs: clip.endMs,
            kind: clip.kind,
            title: clip.title,
            repeats: clip.repeats,
            startSpeed: clip.startSpeed,
            endSpeed: clip.endSpeed,
            languageCode: clip.languageCode
        )
        
        // Update working clips in memory
        workingClips[session.currentClipIndex] = clip1
        workingClips.insert(clip2, at: session.currentClipIndex + 1)
        
        // Update session to point to new clip (index + 1)
        var updatedSession = session
        updatedSession.currentClipIndex = session.currentClipIndex + 1
        updatedSession.currentLoopCount = 0
        
        do {
            try practiceService.saveSession(updatedSession)
            currentSession = updatedSession
        } catch {
            print("Failed to save session: \(error)")
        }
        
        // Mark as having unsaved changes
        hasUnsavedChanges = true
        
        // Reload table view
        tableView.reloadData()
        
        // Success feedback
        let successGenerator = UINotificationFeedbackGenerator()
        successGenerator.notificationOccurred(.success)
    }
    
    @objc private func mergeButtonTapped() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        guard let session = currentSession,
              session.currentClipIndex > 0,
              session.currentClipIndex < workingClips.count else { return }
        
        mergeClipUp(at: session.currentClipIndex)
    }

    // MARK: - Public Methods
    
    func loadTrackAndPracticeSet(track: Track, practiceSet: PracticeSet) {
        // Log incoming track and practice set
        print("🎯 [PracticeViewController] loadTrackAndPracticeSet called:")
        print("  Track ID: \(track.id)")
        print("  Track Title: \(track.title)")
        print("  Track Filename: \(track.filename)")
        print("  Track Pack ID: \(track.packId)")
        print("  Track Duration: \(track.durationMs ?? -1)ms")
        print("  Practice Set ID: \(practiceSet.id)")
        print("  Practice Set Title: \(practiceSet.title ?? "nil")")
        print("  Practice Set Clips Count: \(practiceSet.clips.count)")
        
        // Log drill clips
        let drillClips = practiceSet.clips.filter { $0.kind == .drill }
        print("  Drill clips count: \(drillClips.count)")
        for (index, clip) in drillClips.enumerated() {
            print("  DrillClip[\(index)]: startMs=\(clip.startMs), endMs=\(clip.endMs)")
        }
        
        // Set the track and practice set ID
        selectedPracticeSetId = practiceSet.id
        selectedTrack = track  // This will trigger refreshDataAsync
    }
    
    // MARK: - Helpers

    private func presentAlert(_ title: String, _ message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
    
    private func stopCurrentPlayback() {
        if isPlaying || isPaused {
            player.stop()
            isPlaying = false
            isPaused = false
            updatePlayPauseButton()
        }
    }
    
    func resetClipToZero(at index: Int) {
        guard var session = currentSession, index < workingClips.count else { return }
        
        let clipId = workingClips[index].id
        session.clipPlayCounts[clipId] = 0
        
        // If this is the current clip, also reset loop count
        if session.currentClipIndex == index {
            session.currentLoopCount = 0
        }
        
        do {
            try practiceService.saveSession(session)
            currentSession = session
            
            let indexPath = IndexPath(row: index, section: 0)
            tableView.reloadRows(at: [indexPath], with: .automatic)
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("Failed to reset clip: \(error)")
        }
    }
}

// MARK: - UITableViewDataSource

extension PracticeViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return workingClips.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ClipCell", for: indexPath) as! ClipCell
        
        let clip = workingClips[indexPath.row]
        let totalLoops = settings.globalRepeats
        let currentLoops = currentSession?.clipPlayCounts[clip.id] ?? 0
        let currentSpeed = currentSession?.currentSpeed ?? 1.0
        let isCurrent = (currentSession?.currentClipIndex == indexPath.row) && isPlaying
        let isCompleted = currentLoops >= totalLoops
        let showForeverBadge = (currentSession?.foreverMode ?? false) && isCurrent
        
        cell.configure(
            index: indexPath.row,
            clip: clip,
            currentLoops: currentLoops,
            totalLoops: totalLoops,
            currentSpeed: currentSpeed,
            isCurrent: isCurrent,
            isCompleted: isCompleted,
            showForeverBadge: showForeverBadge
        )
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension PracticeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        guard var session = currentSession else { return }
        
        let selectedClip = workingClips[indexPath.row]
        
        // If user taps a non-drill clip, find the next drill clip
        if selectedClip.kind != .drill {
            // Find next drill clip after the selected index
            if let nextDrillIndex = workingClips[indexPath.row...].firstIndex(where: { $0.kind == .drill }) {
                session.currentClipIndex = nextDrillIndex
                presentAlert("Skipping to Drill", "Selected clip is marked as \(selectedClip.kind.label). Jumping to next drill clip.")
            } else if let firstDrillIndex = workingClips.firstIndex(where: { $0.kind == .drill }) {
                // No drill after this point, wrap to first drill
                session.currentClipIndex = firstDrillIndex
                presentAlert("Skipping to Drill", "Selected clip is marked as \(selectedClip.kind.label). Jumping to first drill clip.")
            } else {
                // No drills at all
                presentAlert("No Drills", "This track has no drill clips to practice")
                return
            }
        } else {
            // Jump to selected drill clip
            session.currentClipIndex = indexPath.row
        }
        
        session.currentLoopCount = 0  // Reset loop count for new clip
        
        do {
            try practiceService.saveSession(session)
            currentSession = session
            
            // Start practice at the selected clip (whether already playing or not)
            startPractice()
            
            tableView.reloadData()
            updateProgressLabel()
        } catch {
            print("Failed to update session: \(error)")
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let resetAction = UIContextualAction(style: .destructive, title: "Reset") { [weak self] _, _, completion in
            self?.resetClipToZero(at: indexPath.row)
            completion(true)
        }
        
        resetAction.backgroundColor = .systemRed
        resetAction.image = UIImage(systemName: "arrow.counterclockwise")
        
        return UISwipeActionsConfiguration(actions: [resetAction])
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let clip = workingClips[indexPath.row]
        var actions: [UIContextualAction] = []
        
        // Always show all three kind options
        // Order from right to left as they appear when swiping: Noise, Skip, Drill
        
        // Noise (rightmost when swiping)
        let noiseAction = UIContextualAction(style: .normal, title: "Noise") { [weak self] _, _, completion in
            self?.setClipKind(at: indexPath.row, to: .noise)
            completion(true)
        }
        noiseAction.backgroundColor = .systemGray
        noiseAction.image = UIImage(systemName: "speaker.slash.circle")
        actions.append(noiseAction)
        
        // Skip (middle)
        let skipAction = UIContextualAction(style: .normal, title: "Skip") { [weak self] _, _, completion in
            self?.setClipKind(at: indexPath.row, to: .skip)
            completion(true)
        }
        skipAction.backgroundColor = .systemOrange
        skipAction.image = UIImage(systemName: "forward.circle")
        actions.append(skipAction)
        
        // Drill (leftmost when swiping)
        let drillAction = UIContextualAction(style: .normal, title: "Drill") { [weak self] _, _, completion in
            self?.setClipKind(at: indexPath.row, to: .drill)
            completion(true)
        }
        drillAction.backgroundColor = .systemGreen
        drillAction.image = UIImage(systemName: "checkmark.circle")
        actions.append(drillAction)
        
        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = false  // Prevent accidental full swipe
        return config
    }
}

// MARK: - Clip Editing Helpers

extension PracticeViewController {
    
    func mergeClipUp(at index: Int) {
        guard index > 0, index < workingClips.count else { return }
        
        var currentClip = workingClips[index]
        var previousClip = workingClips[index - 1]
        
        // Merge: extend previous clip to end of current clip
        previousClip.endMs = currentClip.endMs
        
        // Update working clips in memory
        workingClips[index - 1] = previousClip
        workingClips.remove(at: index)
        
        // Update session if this was the current clip
        if var session = currentSession, session.currentClipIndex == index {
            session.currentClipIndex = index - 1
            do {
                try practiceService.saveSession(session)
                currentSession = session
            } catch {
                print("Failed to save session: \(error)")
            }
        }
        
        // Mark as having unsaved changes
        hasUnsavedChanges = true
        
        // Reload table view
        tableView.reloadData()
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func setClipKind(at index: Int, to kind: ClipKind) {
        guard index < workingClips.count else { return }
        
        var clip = workingClips[index]
        clip.kind = kind
        workingClips[index] = clip
        
        // Mark as having unsaved changes
        hasUnsavedChanges = true
        
        // Reload the specific row
        let indexPath = IndexPath(row: index, section: 0)
        tableView.reloadRows(at: [indexPath], with: .automatic)
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}
