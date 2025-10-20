//
//  AudioPlayerServiceAVPlayer.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//
// path: Services/AudioPlayerServiceAVPlayer.swift
import Foundation
import UIKit
import AVFoundation
import MediaPlayer

final class AudioPlayerServiceAVPlayer: NSObject, AudioPlayerService {
    private var player: AVPlayer?
    private var itemEndObserver: Any?
    private var timeObserverToken: Any?

    private(set) var isPlaying: Bool = false

    // Scheduling
    private var pendingWorkItem: DispatchWorkItem?

    // Whole-track mode
    private var wholeTrackRepeatsRemaining: Int = 0
    private var wholeTrackGapSeconds: TimeInterval = 0.5

    // Clip mode
    private var currentTrack: Track?
    private var trackURL: URL?
    private var clipsQueue: [Clip] = []
    private var currentSegmentIndex: Int = 0
    private var currentSegmentRepeatsRemaining: Int = 0
    private var globalRepeats: Int = 1
    private var gapSeconds: TimeInterval = 0.5
    private var interClipGapSeconds: TimeInterval = 0.5
    private var prerollSeconds: TimeInterval = 0.0
    private var currentSegmentStart: CMTime = .zero
    private var currentSegmentEnd: CMTime = .zero
    private let pollInterval = CMTime(seconds: 0.01, preferredTimescale: 600) // 10ms
    private let epsilon: Double = 0.005 // 5ms

    // Practice session tracking
    private let practiceService: PracticeService
    private let settings: SettingsService
    private var currentSession: PracticeSession?
    private var totalLoopsForCurrentClip: Int = 0
    private var foreverMode: Bool = false
    
    // MARK: - Media Player
    
    // Remote command / now playing
    private var nowPlayingInfo: [String: Any] = [:]
    
    // Interruption state
    private var shouldResumeAfterInterruption = false
    
    // MARK: - Init
    
    init(practiceService: PracticeService, settings: SettingsService) {
        self.practiceService = practiceService
        self.settings = settings
        super.init()
    }
    
    // MARK: - Public API

    func play(track: Track, repeats: Int, gapSeconds: TimeInterval) throws {
        // Whole-track convenience (legacy)
        try startWholeTrack(track: track, repeats: repeats, gap: gapSeconds)
    }

    func play(track: Track,
              clips: [Clip],
              globalRepeats: Int,
              gapSeconds: TimeInterval,
              interClipGapSeconds: TimeInterval,
              prerollMs: Int) throws {
        try startSegments(track: track,
                          clips: clips,
                          globalRepeats: globalRepeats,
                          gap: gapSeconds,
                          interGap: interClipGapSeconds,
                          prerollMs: prerollMs,
                          session: nil)
    }
    
    func play(track: Track,
              clips: [Clip],
              globalRepeats: Int,
              gapSeconds: TimeInterval,
              interClipGapSeconds: TimeInterval,
              prerollMs: Int,
              session: PracticeSession?) throws {
        try startSegments(track: track,
                          clips: clips,
                          globalRepeats: globalRepeats,
                          gap: gapSeconds,
                          interGap: interClipGapSeconds,
                          prerollMs: prerollMs,
                          session: session)
    }

    func pause() {
        pendingWorkItem?.cancel()
        player?.pause()
        isPlaying = false
        // no notification on pause
    }

    func resume() {
        player?.play()
        isPlaying = true
        NotificationCenter.default.post(name: .AudioPlayerDidStart, object: nil)
    }

    func stop() {
        pendingWorkItem?.cancel(); pendingWorkItem = nil
        removeObservers()
        
        // MEDIA PLAYER
        disableRemoteCommands()                     // Media Player
        clearNowPlaying()                           // Media Player
        
        player?.pause()
        player = nil
        isPlaying = false
        clipsQueue = []
        currentTrack = nil
        trackURL = nil
        currentSession = nil
        foreverMode = false

        NotificationCenter.default.post(name: .AudioPlayerDidStop, object: nil)
    }

    // MARK: - Whole track

    private func startWholeTrack(track: Track, repeats: Int, gap: TimeInterval) throws {
        stop() // cleanup previous session

        guard let url = resolveURL(for: track) else {
            throw AudioPlayerError.fileNotFound(filename: track.filename)
        }
        try configureSession()

        wholeTrackRepeatsRemaining = max(1, repeats)
        wholeTrackGapSeconds = max(0, gap)

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)

        addSessionNotifications()                   // Media Player
        setupRemoteCommands()                       // Media Player
        updateNowPlaying(track: track,
                         segmentTitle: nil,
                         elapsed: 0,
                         duration: CMTimeGetSeconds(item.asset.duration),
                         rate: 1.0) // MEDIA PLAYER
        
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.wholeTrackRepeatsRemaining -= 1
            if self.wholeTrackRepeatsRemaining > 0 {
                let work = DispatchWorkItem { [weak self] in
                    guard let self = self, let p = self.player else { return }
                    p.seek(to: .zero)
                    p.play()
                }
                self.pendingWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + self.wholeTrackGapSeconds, execute: work)
            } else {
                self.stop() // posts DidStop, clears observers
            }
        }

        player?.play()
        isPlaying = true
        NotificationCenter.default.post(name: .AudioPlayerDidStart, object: nil)
    }

    // MARK: - Clip mode

    private func startSegments(track: Track,
                               clips: [Clip],
                               globalRepeats: Int,
                               gap: TimeInterval,
                               interGap: TimeInterval,
                               prerollMs: Int,
                               session: PracticeSession?) throws {
        stop() // cleanup

        guard let url = resolveURL(for: track) else {
            throw AudioPlayerError.fileNotFound(filename: track.filename)
        }
        try configureSession()

        currentTrack = track
        trackURL = url
        clipsQueue = clips
        self.globalRepeats = max(1, globalRepeats)
        self.gapSeconds = max(0, gap)
        self.interClipGapSeconds = max(0, interGap)
        self.prerollSeconds = max(0, Double(prerollMs) / 1000.0)
        
        // Practice session handling
        self.currentSession = session
        self.foreverMode = session?.foreverMode ?? false
        if let session = session {
            currentSegmentIndex = session.currentClipIndex
        } else {
            currentSegmentIndex = 0
        }

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)

        // Periodic observer to detect end-of-clip
        addPeriodicObserver()

        addSessionNotifications()                   // Media Player
        setupRemoteCommands()                       // Media Player
        
        // Start first clip
        startCurrentSegment()
    }

    private func startCurrentSegment() {
        // Check bounds and handle forever mode
        if currentSegmentIndex < 0 || currentSegmentIndex >= clipsQueue.count {
            // If forever mode and at end, loop back to first clip
            if foreverMode && !clipsQueue.isEmpty {
                currentSegmentIndex = 0
            } else {
                stop()
                return
            }
        }
        
        guard let player = player, let track = currentTrack else {
            stop(); return
        }

        let seg = clipsQueue[currentSegmentIndex]
        
        // Determine total loops and restore progress if resuming session
        totalLoopsForCurrentClip = max(1, seg.repeats ?? globalRepeats)
        if let session = currentSession, session.currentClipIndex == currentSegmentIndex {
            currentSegmentRepeatsRemaining = totalLoopsForCurrentClip - session.currentLoopCount
        } else {
            currentSegmentRepeatsRemaining = totalLoopsForCurrentClip
        }

        currentSegmentStart = CMTime(seconds: Double(seg.startMs) / 1000.0, preferredTimescale: 600)
        currentSegmentEnd   = CMTime(seconds: Double(seg.endMs)   / 1000.0, preferredTimescale: 600)

        let seekStart = max(0, currentSegmentStart.seconds - prerollSeconds)
        let seekTime = CMTime(seconds: seekStart, preferredTimescale: 600)
        
        // Calculate speed for current loop
        let currentLoop = totalLoopsForCurrentClip - currentSegmentRepeatsRemaining
        let speed = practiceService.calculateSpeed(
            mode: settings.speedMode,
            currentLoop: currentLoop,
            totalLoops: totalLoopsForCurrentClip,
            minSpeed: settings.minSpeed,
            maxSpeed: settings.maxSpeed,
            modeN: settings.speedModeN
        )
        
        // Seek precisely to start and play
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self else { return }
            self.player?.rate = speed
            self.isPlaying = true
            
            // Update session with current speed
            if var session = self.currentSession {
                do {
                    try self.practiceService.updateProgress(
                        session: &session,
                        clipIndex: self.currentSegmentIndex,
                        loopCount: currentLoop,
                        speed: speed
                    )
                    self.currentSession = session
                } catch {
                    print("Failed to update practice session: \(error)")
                }
            }
            
            // Update Now Playing for this clip (duration is clip length)
            let segDuration = self.currentSegmentEnd.seconds - self.currentSegmentStart.seconds // Media Player
            self.updateNowPlaying(track: track,
                                  segmentTitle: seg.title,
                                  elapsed: 0,
                                  duration: max(0.01, segDuration),
                                  rate: speed) // Media Player
            
            // Post clip change notification
            NotificationCenter.default.post(
                name: .AudioPlayerClipDidChange,
                object: nil,
                userInfo: ["clipIndex": self.currentSegmentIndex, "clipId": seg.id]
            )
            
            // Post speed change notification
            NotificationCenter.default.post(
                name: .AudioPlayerSpeedDidChange,
                object: nil,
                userInfo: ["speed": speed]
            )
            
            NotificationCenter.default.post(name: .AudioPlayerDidStart, object: nil)
        }
    }

    private func handleSegmentTick(_ time: CMTime) {
        // End-of-clip detection
        guard isPlaying else { return }
        
        // Update elapsed in Now Playing (ignoring preroll; shows progress of the actual clip)
        let elapsed = max(0, time.seconds - currentSegmentStart.seconds)
        updateNowPlayingElapsed(elapsed)
        
        // Post time update for UI (track time and clip bounds)
        let trackTimeMs = Int(time.seconds * 1000)
        let clipStartMs = Int(currentSegmentStart.seconds * 1000)
        let clipEndMs = Int(currentSegmentEnd.seconds * 1000)
        
        NotificationCenter.default.post(
            name: .AudioPlayerDidUpdateTime,
            object: nil,
            userInfo: [
                "trackTimeMs": trackTimeMs,
                "clipStartMs": clipStartMs,
                "clipEndMs": clipEndMs
            ]
        )
        
        if time.seconds >= currentSegmentEnd.seconds - epsilon {
            // Stop immediately to avoid hearing audio past end
            player?.pause()
            isPlaying = false

            // Update practice session - increment play count for this clip
            if var session = currentSession {
                let seg = clipsQueue[currentSegmentIndex]
                do {
                    try practiceService.incrementClipPlayCount(session: &session, clipId: seg.id)
                    currentSession = session
                } catch {
                    print("Failed to increment clip play count: \(error)")
                }
            }

            // Post loop complete notification
            NotificationCenter.default.post(
                name: .AudioPlayerLoopDidComplete,
                object: nil,
                userInfo: [
                    "clipIndex": self.currentSegmentIndex,
                    "loopCount": self.totalLoopsForCurrentClip - self.currentSegmentRepeatsRemaining + 1
                ]
            )

            currentSegmentRepeatsRemaining -= 1
            if currentSegmentRepeatsRemaining > 0 {
                // repeat same clip after gap
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }

                    let seekStart = max(0, self.currentSegmentStart.seconds - self.prerollSeconds)
                    let seekTime = CMTime(seconds: seekStart, preferredTimescale: 600)
                    
                    // Calculate speed for next loop
                    let currentLoop = self.totalLoopsForCurrentClip - self.currentSegmentRepeatsRemaining
                    let speed = self.practiceService.calculateSpeed(
                        mode: self.settings.speedMode,
                        currentLoop: currentLoop,
                        totalLoops: self.totalLoopsForCurrentClip,
                        minSpeed: self.settings.minSpeed,
                        maxSpeed: self.settings.maxSpeed,
                        modeN: self.settings.speedModeN
                    )

                    self.player?.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                        self.player?.rate = speed
                        self.isPlaying = true
                        
                        // Update session with current loop and speed
                        if var session = self.currentSession {
                            do {
                                try self.practiceService.updateProgress(
                                    session: &session,
                                    clipIndex: self.currentSegmentIndex,
                                    loopCount: currentLoop,
                                    speed: speed
                                )
                                self.currentSession = session
                            } catch {
                                print("Failed to update practice session: \(error)")
                            }
                        }
                        
                        // Post speed change notification
                        NotificationCenter.default.post(
                            name: .AudioPlayerSpeedDidChange,
                            object: nil,
                            userInfo: ["speed": speed]
                        )
                        
                        // reset elapsed for new loop
                        self.updateNowPlayingElapsed(0)
                        NotificationCenter.default.post(name: .AudioPlayerDidStart, object: nil)
                    }
                }
                pendingWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + gapSeconds, execute: work)
            } else {
                // advance to next clip after inter-clip gap
                currentSegmentIndex += 1
                let work = DispatchWorkItem { [weak self] in
                    self?.startCurrentSegment()
                }
                pendingWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + interClipGapSeconds, execute: work)
            }
        }
    }

    // MARK: - Observers

    private func addPeriodicObserver() {
        removePeriodicObserver()
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: pollInterval, queue: .main, using: { [weak self] time in
            self?.handleSegmentTick(time)
        })
    }

    private func removePeriodicObserver() {
        if let tok = timeObserverToken, let p = player {
            p.removeTimeObserver(tok)
            timeObserverToken = nil
        }
    }

    private func removeObservers() {
        if let end = itemEndObserver {
            NotificationCenter.default.removeObserver(end)
            itemEndObserver = nil
        }
        removePeriodicObserver()
        
        // Media Player
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)

    }

    // MARK: - Utilities

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        
        // Configure audio session for background playback and media controls
        // Read duck others preference from settings
        let duck = (AppContainer().settings.duckOthers)
        var opts: AVAudioSession.CategoryOptions = [.mixWithOthers, .allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
        if duck { 
            opts.insert(.duckOthers) 
        }
        
        // Use .playback category to enable background audio and lock screen controls
        // Mode .spokenAudio is better for language learning content
        try session.setCategory(.playback, mode: .spokenAudio, options: opts)
        try session.setActive(true, options: [])
    }

    private func resolveURL(for track: Track) -> URL? {
        let filename = track.filename
        let ext = (filename as NSString).pathExtension
        let base = (filename as NSString).deletingPathExtension

        // 1) Bundle
        if !base.isEmpty, let u = Bundle.main.url(forResource: base, withExtension: ext.isEmpty ? nil : ext) {
            return u
        }

        // 2) Documents/LanguageMirror/library/packs/<track.packId>/tracks/<track.id>/<filename>
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let inTrackDir = docs
                .appendingPathComponent("LanguageMirror", isDirectory: true)
                .appendingPathComponent("library", isDirectory: true)
                .appendingPathComponent("packs", isDirectory: true)
                .appendingPathComponent(track.packId, isDirectory: true)
                .appendingPathComponent("tracks", isDirectory: true)
                .appendingPathComponent(track.id, isDirectory: true)
                .appendingPathComponent(filename)

            if FileManager.default.fileExists(atPath: inTrackDir.path) {
                return inTrackDir
            }

            // 3) Documents root fallback
            let inDocs = docs.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: inDocs.path) {
                return inDocs
            }
        }

        return nil
    }
    
    private func addSessionNotifications() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil)

        NotificationCenter.default.addObserver(self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification, object: nil)
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }

        switch type {
        case .began:
            shouldResumeAfterInterruption = isPlaying
            pause()
        case .ended:
            let optsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let opts = AVAudioSession.InterruptionOptions(rawValue: optsRaw)
            if shouldResumeAfterInterruption && opts.contains(.shouldResume) {
                resume()
            }
            shouldResumeAfterInterruption = false
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ note: Notification) {
        guard let info = note.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        if reason == .oldDeviceUnavailable {
            // e.g., headphones unplugged -> pause politely
            if isPlaying { pause() }
        }
    }
    
    // MARK: - Remote Command Center

    private func setupRemoteCommands() {
        disableRemoteCommands()

        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.stopCommand.isEnabled = true

        // Register command handlers (removed duplicate registrations)
        center.playCommand.addTarget { [weak self] _ in 
            self?.resume()
            return .success 
        }
        center.pauseCommand.addTarget { [weak self] _ in 
            self?.pause()
            return .success 
        }
        center.stopCommand.addTarget { [weak self] _ in 
            self?.stop()
            return .success 
        }

        // (Optional) Next/Previous as clip skip:
        // center.nextTrackCommand.isEnabled = true
        // center.previousTrackCommand.isEnabled = true
        // center.nextTrackCommand.addTarget { [weak self] _ in self?.skipToNextSegment(); return .success }
        // center.previousTrackCommand.addTarget { [weak self] _ in self?.skipToPreviousSegment(); return .success }
    }

    private func disableRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.stopCommand.removeTarget(nil)
        
        // Disable to clean up UI when not playing
        center.playCommand.isEnabled = false
        center.pauseCommand.isEnabled = false
        center.stopCommand.isEnabled = false
        // center.nextTrackCommand.isEnabled = false
        // center.previousTrackCommand.isEnabled = false
    }

    // MARK: - Now Playing

    private func updateNowPlaying(track: Track,
                                  segmentTitle: String?,
                                  elapsed: Double,
                                  duration: Double,
                                  rate: Float) {
        var info: [String: Any] = [:]
        
        // Track/clip title - unwrap segmentTitle properly
        let displayTitle: String
        if let segment = segmentTitle, !segment.isEmpty {
            displayTitle = segment
        } else {
            displayTitle = track.title
        }
        
        info[MPMediaItemPropertyTitle] = displayTitle
        info[MPMediaItemPropertyAlbumTitle] = "LanguageMirror"
        info[MPMediaItemPropertyArtist] = "Practice Session"
        
        // Playback info
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        
        // Add artwork for better lock screen presence
        // Create a simple placeholder image with app icon or text
        if let artwork = createPlaceholderArtwork(title: displayTitle) {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func createPlaceholderArtwork(title: String) -> MPMediaItemArtwork? {
        // Create a simple colored square with text
        let size = CGSize(width: 300, height: 300)
        
        return MPMediaItemArtwork(boundsSize: size) { size in
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                // Background gradient
                let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors as CFArray,
                                            locations: [0.0, 1.0]) {
                    context.cgContext.drawLinearGradient(gradient,
                                                        start: CGPoint(x: 0, y: 0),
                                                        end: CGPoint(x: size.width, y: size.height),
                                                        options: [])
                }
                
                // Add app icon or text
                let text = "🎧"
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 120, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let textSize = text.size(withAttributes: attributes)
                let textRect = CGRect(x: (size.width - textSize.width) / 2,
                                     y: (size.height - textSize.height) / 2,
                                     width: textSize.width,
                                     height: textSize.height)
                text.draw(in: textRect, withAttributes: attributes)
            }
        }
    }

    private func updateNowPlayingElapsed(_ elapsed: Double) {
        guard !nowPlayingInfo.isEmpty else { return }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func clearNowPlaying() {
        nowPlayingInfo.removeAll()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // (Optional) clip skip for remote next/prev:
    // private func skipToNextSegment() { currentSegmentIndex = min(currentSegmentIndex+1, clipsQueue.count); startCurrentSegment() }
    // private func skipToPreviousSegment() { currentSegmentIndex = max(0, currentSegmentIndex-1); startCurrentSegment() }



}
