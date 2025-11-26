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
    weak var delegate: AudioPlayerDelegate?

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
    /// When true, the first clip in the next `startSegments` run should be
    /// played once even if its historical play count already meets the
    /// effective loop target.
    private var forcePlayFirstClipOnce: Bool = false
    
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
                          session: nil,
                          forcePlayFirstClipOnce: false)
    }
    
    func play(track: Track,
              clips: [Clip],
              globalRepeats: Int,
              gapSeconds: TimeInterval,
              interClipGapSeconds: TimeInterval,
              prerollMs: Int,
              session: PracticeSession?,
              forcePlayFirstClipOnce: Bool = false) throws {
        try startSegments(track: track,
                          clips: clips,
                          globalRepeats: globalRepeats,
                          gap: gapSeconds,
                          interGap: interClipGapSeconds,
                          prerollMs: prerollMs,
                          session: session,
                          forcePlayFirstClipOnce: forcePlayFirstClipOnce)
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
        delegate?.audioPlayerDidResume()
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
        forcePlayFirstClipOnce = false

        delegate?.audioPlayerDidStop()
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
        delegate?.audioPlayerDidStart()
    }

    // MARK: - Clip mode

    private func startSegments(track: Track,
                               clips: [Clip],
                               globalRepeats: Int,
                               gap: TimeInterval,
                               interGap: TimeInterval,
                               prerollMs: Int,
                               session: PracticeSession?,
                               forcePlayFirstClipOnce: Bool) throws {
        print("🎵 [AudioPlayerServiceAVPlayer] startSegments called:")
        print("  Track filename: \(track.filename)")
        print("  Track ID: \(track.id)")
        print("  Pack ID: \(track.packId)")
        print("  Clips count: \(clips.count)")
        print("  Global repeats: \(globalRepeats)")
        print("  Gap seconds: \(gap)")
        print("  Inter-clip gap seconds: \(interGap)")
        print("  Preroll ms: \(prerollMs)")
        
        // Log all clip times
        for (index, clip) in clips.enumerated() {
            print("  Clip[\(index)]: startMs=\(clip.startMs), endMs=\(clip.endMs), kind=\(clip.kind.rawValue)")
        }
        
        stop() // cleanup

        print("  Resolving audio file URL...")
        guard let url = resolveURL(for: track) else {
            print("❌ [AudioPlayerServiceAVPlayer] Audio file not found: \(track.filename)")
            throw AudioPlayerError.fileNotFound(filename: track.filename)
        }
        print("✅ [AudioPlayerServiceAVPlayer] Resolved URL: \(url.path)")
        
        print("  Configuring audio session...")
        try configureSession()
        print("✅ [AudioPlayerServiceAVPlayer] Audio session configured")

        currentTrack = track
        trackURL = url
        clipsQueue = clips
        self.globalRepeats = max(1, globalRepeats)
        self.gapSeconds = max(0, gap)
        self.interClipGapSeconds = max(0, interGap)
        self.prerollSeconds = max(0, Double(prerollMs) / 1000.0)
        
        // Practice session handling
        self.currentSession = session
        self.forcePlayFirstClipOnce = forcePlayFirstClipOnce
        if let session = session {
            currentSegmentIndex = session.currentClipIndex
            print("  Using session clip index: \(currentSegmentIndex)")
        } else {
            currentSegmentIndex = 0
            print("  Starting at clip index: 0")
        }

        print("  Creating AVPlayerItem with URL: \(url.path)")
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        print("✅ [AudioPlayerServiceAVPlayer] AVPlayer created")

        // Periodic observer to detect end-of-clip
        addPeriodicObserver()

        addSessionNotifications()                   // Media Player
        setupRemoteCommands()                       // Media Player
        
        // Start first clip
        print("  Starting first segment...")
        startCurrentSegment()
    }

    private func startCurrentSegment() {
        print("  🎬 [AudioPlayerServiceAVPlayer] startCurrentSegment - index: \(currentSegmentIndex)")
        
        // Check bounds – if we're past the end, treat as \"all clips completed\"
        if currentSegmentIndex < 0 || currentSegmentIndex >= clipsQueue.count {
            print("    ⚠️ Clip index out of bounds: \(currentSegmentIndex) (queue size: \(clipsQueue.count))")
            handleAllClipsCompleted()
            return
        }
        
        guard let player = player, let track = currentTrack else {
            print("    ❌ Player or track is nil")
            stop(); return
        }

        let seg = clipsQueue[currentSegmentIndex]
        print("    Clip[\(currentSegmentIndex)]: startMs=\(seg.startMs), endMs=\(seg.endMs)")
        
        // Get track duration for validation
        let trackDurationMs = track.durationMs ?? Int.max
        print("    Track duration: \(trackDurationMs)ms")
        
        // Validate clip times to prevent error -50
        guard seg.startMs >= 0, seg.endMs > seg.startMs else {
            print("    ❌ Invalid clip times: startMs=\(seg.startMs), endMs=\(seg.endMs)")
            // Skip to next clip
            currentSegmentIndex += 1
            startCurrentSegment()
            return
        }
        
        // Validate clip doesn't exceed track duration
        if seg.endMs > trackDurationMs {
            print("    ⚠️ Clip endMs (\(seg.endMs)) exceeds track duration (\(trackDurationMs)). Clamping to track duration.")
        }
        
        // Clamp end time to track duration to prevent seeking beyond file
        let clampedEndMs = min(seg.endMs, trackDurationMs)
        
        // Determine total loops and remaining loops based on session history
        totalLoopsForCurrentClip = effectiveLoopTarget(for: seg)
        var loopsRemaining: Int
        
        if let session = currentSession {
            let played = max(0, session.clipPlayCounts[seg.id] ?? 0)
            loopsRemaining = max(totalLoopsForCurrentClip - played, 0)
            
            // One-time override: if caller requested that the first clip be
            // played once even when completed, honor that here.
            if forcePlayFirstClipOnce && loopsRemaining == 0 {
                print("    Force-playing completed clip once (forcePlayFirstClipOnce=true)")
                loopsRemaining = 1
            }
            
            // Clear the override after first use so it doesn't leak to later clips.
            if forcePlayFirstClipOnce {
                forcePlayFirstClipOnce = false
            }
            
            if loopsRemaining == 0 {
                print("    Clip already completed under current settings, searching for next incomplete clip...")
                if let nextIndex = findNextIncompleteClip(startingAt: currentSegmentIndex + 1, session: session) {
                    print("    Moving to next incomplete clip at index \(nextIndex)")
                    currentSegmentIndex = nextIndex
                    startCurrentSegment()
                } else {
                    print("    No incomplete clips remain")
                    handleAllClipsCompleted()
                }
                return
            }
        } else {
            // No persistent session – fall back to simple repeat behavior.
            loopsRemaining = totalLoopsForCurrentClip
        }
        
        currentSegmentRepeatsRemaining = loopsRemaining

        currentSegmentStart = CMTime(seconds: Double(seg.startMs) / 1000.0, preferredTimescale: 600)
        currentSegmentEnd   = CMTime(seconds: Double(clampedEndMs)   / 1000.0, preferredTimescale: 600)
        
        print("    CMTime start: \(currentSegmentStart.seconds)s")
        print("    CMTime end: \(currentSegmentEnd.seconds)s")

        let seekStart = max(0, currentSegmentStart.seconds - prerollSeconds)
        let seekTime = CMTime(seconds: seekStart, preferredTimescale: 600)
        print("    Seek time (with preroll): \(seekTime.seconds)s")
        
        // Calculate speed for current loop
        let currentLoop = totalLoopsForCurrentClip - currentSegmentRepeatsRemaining
        let speed = practiceService.calculateSpeed(
            useProgressionMode: settings.useProgressionMode,
            currentLoop: currentLoop,
            progressionMinRepeats: settings.progressionMinRepeats,
            progressionLinearRepeats: settings.progressionLinearRepeats,
            progressionMaxRepeats: settings.progressionMaxRepeats,
            minSpeed: settings.minSpeed,
            maxSpeed: settings.maxSpeed
        )
        print("    Speed: \(speed)x")
        
        // Seek precisely to start and play
        print("    Seeking to \(seekTime.seconds)s...")
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard let self else { return }
            print("    ✅ Seek completed (finished: \(finished))")
            print("    Setting playback rate to \(speed)x and starting...")
            self.player?.rate = speed
            self.isPlaying = true
            
            // Update session with current speed and loop index
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
                    print("    ⚠️ Failed to update practice session: \(error)")
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
            print("📢 [AudioPlayerServiceAVPlayer] Calling delegate clipDidChange")
            delegate?.audioPlayerClipDidChange(clipIndex: self.currentSegmentIndex, clipId: seg.id)
            
            // Post speed change notification
            delegate?.audioPlayerSpeedDidChange(speed: speed)
            
            delegate?.audioPlayerDidStart()
            print("    ✅ Clip playback started")
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
        
        delegate?.audioPlayerDidUpdateTime(trackTimeMs: trackTimeMs, clipStartMs: clipStartMs, clipEndMs: clipEndMs)
        
        if time.seconds >= currentSegmentEnd.seconds - epsilon {
            // Stop immediately to avoid hearing audio past end
            player?.pause()
            isPlaying = false

            if var session = currentSession {
                let seg = clipsQueue[currentSegmentIndex]
                do {
                    print("🔄 [AudioPlayerServiceAVPlayer] Calling incrementClipPlayCount for clip: \(seg.id)")
                    try practiceService.incrementClipPlayCount(session: &session, clipId: seg.id)
                    currentSession = session
                    print("✅ [AudioPlayerServiceAVPlayer] Session updated successfully")
                } catch {
                    print("Failed to increment clip play count: \(error)")
                }
                
                // Recompute remaining loops using up-to-date play counts
                let target = effectiveLoopTarget(for: seg)
                let played = max(0, session.clipPlayCounts[seg.id] ?? 0)
                totalLoopsForCurrentClip = target
                currentSegmentRepeatsRemaining = max(target - played, 0)
                
                // Post loop complete notification with the true play count
                print("📢 [AudioPlayerServiceAVPlayer] Calling delegate loopDidComplete")
                delegate?.audioPlayerLoopDidComplete(clipIndex: currentSegmentIndex, loopCount: played)
                
                if currentSegmentRepeatsRemaining > 0 {
                    // repeat same clip after gap
                    let work = DispatchWorkItem { [weak self] in
                        guard let self else { return }

                        let seekStart = max(0, self.currentSegmentStart.seconds - self.prerollSeconds)
                        let seekTime = CMTime(seconds: seekStart, preferredTimescale: 600)
                        
                        // Calculate speed for next loop
                        let currentLoop = self.totalLoopsForCurrentClip - self.currentSegmentRepeatsRemaining
                        let speed = self.practiceService.calculateSpeed(
                            useProgressionMode: self.settings.useProgressionMode,
                            currentLoop: currentLoop,
                            progressionMinRepeats: self.settings.progressionMinRepeats,
                            progressionLinearRepeats: self.settings.progressionLinearRepeats,
                            progressionMaxRepeats: self.settings.progressionMaxRepeats,
                            minSpeed: self.settings.minSpeed,
                            maxSpeed: self.settings.maxSpeed
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
                            self.delegate?.audioPlayerSpeedDidChange(speed: speed)
                            
                            // reset elapsed for new loop
                            self.updateNowPlayingElapsed(0)
                            self.delegate?.audioPlayerDidStart()
                        }
                    }
                    pendingWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + gapSeconds, execute: work)
                } else {
                    // advance to next incomplete clip after inter-clip gap
                    let work = DispatchWorkItem { [weak self] in
                        guard let self else { return }
                        if let nextIndex = self.findNextIncompleteClip(startingAt: self.currentSegmentIndex + 1, session: self.currentSession) {
                            self.currentSegmentIndex = nextIndex
                            self.startCurrentSegment()
                        } else {
                            self.handleAllClipsCompleted()
                        }
                    }
                    pendingWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + interClipGapSeconds, execute: work)
                }
            } else {
                // No persistent session – fall back to simple repeat behavior using in-memory counters.
                print("📢 [AudioPlayerServiceAVPlayer] Loop complete (no session)")
                let loopCount = totalLoopsForCurrentClip - currentSegmentRepeatsRemaining + 1
                delegate?.audioPlayerLoopDidComplete(clipIndex: currentSegmentIndex, loopCount: loopCount)

                currentSegmentRepeatsRemaining -= 1
                if currentSegmentRepeatsRemaining > 0 {
                    let work = DispatchWorkItem { [weak self] in
                        guard let self else { return }

                        let seekStart = max(0, self.currentSegmentStart.seconds - self.prerollSeconds)
                        let seekTime = CMTime(seconds: seekStart, preferredTimescale: 600)
                        
                        let currentLoop = self.totalLoopsForCurrentClip - self.currentSegmentRepeatsRemaining
                        let speed = self.practiceService.calculateSpeed(
                            useProgressionMode: self.settings.useProgressionMode,
                            currentLoop: currentLoop,
                            progressionMinRepeats: self.settings.progressionMinRepeats,
                            progressionLinearRepeats: self.settings.progressionLinearRepeats,
                            progressionMaxRepeats: self.settings.progressionMaxRepeats,
                            minSpeed: self.settings.minSpeed,
                            maxSpeed: self.settings.maxSpeed
                        )

                        self.player?.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                            self.player?.rate = speed
                            self.isPlaying = true
                            self.delegate?.audioPlayerSpeedDidChange(speed: speed)
                            self.updateNowPlayingElapsed(0)
                            self.delegate?.audioPlayerDidStart()
                        }
                    }
                    pendingWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + gapSeconds, execute: work)
                } else {
                    currentSegmentIndex += 1
                    let work = DispatchWorkItem { [weak self] in
                        self?.startCurrentSegment()
                    }
                    pendingWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + interClipGapSeconds, execute: work)
                }
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

    /// Effective loop target for a clip, honoring per-clip overrides when present.
    private func effectiveLoopTarget(for clip: Clip) -> Int {
        if settings.useProgressionMode {
            // In progression mode, derive the loop target from the progression
            // settings (M + N + O) unless the clip overrides it.
            let progressionTotal = settings.progressionMinRepeats
                + settings.progressionLinearRepeats
                + settings.progressionMaxRepeats
            let base = clip.repeats ?? progressionTotal
            return max(1, base)
        } else {
            // In simple mode, fall back to globalRepeats (or per-clip override).
            let base = clip.repeats ?? globalRepeats
            return max(1, base)
        }
    }
    
    /// Find the next clip index at or after `startingAt` whose play count is
    /// still below its effective loop target. Returns `nil` if none found.
    private func findNextIncompleteClip(startingAt index: Int, session: PracticeSession?) -> Int? {
        guard let session = session, !clipsQueue.isEmpty else { return nil }
        guard index >= 0 else { return nil }
        
        var i = index
        while i < clipsQueue.count {
            let clip = clipsQueue[i]
            let target = effectiveLoopTarget(for: clip)
            let played = max(0, session.clipPlayCounts[clip.id] ?? 0)
            if played < target {
                return i
            }
            i += 1
        }
        return nil
    }

    /// Handle the situation where there are no remaining clips that still need
    /// practice under the current repeat settings.
    private func handleAllClipsCompleted() {
        guard let session = currentSession else {
            print("    No session; stopping playback")
            stop()
            return
        }
        
        if session.foreverMode {
            print("    Forever mode ON – creating a brand new practice session and restarting from first clip")
            
            // Create a brand new session with the same practiceSet/pack/track,
            // but fresh play counts. Preserve foreverMode so behavior continues.
            var newSession = PracticeSession(
                practiceSetId: session.practiceSetId,
                packId: session.packId,
                trackId: session.trackId
            )
            newSession.foreverMode = true
            
            do {
                try practiceService.saveSession(newSession)
                currentSession = newSession
                // Notify delegates so any UI (e.g., PracticeViewController) can
                // update their local `currentSession` reference and refresh UI.
                delegate?.audioPlayerSessionDidReset(newSession)
            } catch {
                print("    ⚠️ Failed to save new session while resetting for forever mode: \(error)")
            }
            
            currentSegmentIndex = 0
            startCurrentSegment()
        } else {
            print("    All clips completed; stopping playback (forever mode OFF)")
            stop()
        }
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        
        print("  🔊 [AudioPlayerServiceAVPlayer] Configuring audio session...")
        
        // Configure audio session for background playback and media controls
        // Read duck others preference from settings
        let duck = (AppContainer().settings.duckOthers)
        
        // For .playback category, we don't use .mixWithOthers (that's for playAndRecord)
        // Instead, use .duckOthers if requested, plus Bluetooth/AirPlay support
        var opts: AVAudioSession.CategoryOptions = []
        if duck { 
            opts.insert(.duckOthers) 
        }
        // Always allow Bluetooth and AirPlay for better user experience
        opts.insert(.allowBluetooth)
        opts.insert(.allowBluetoothA2DP)
        opts.insert(.allowAirPlay)
        
        print("    Current category: \(session.category.rawValue)")
        print("    Current mode: \(session.mode.rawValue)")
        print("    Target category: playback")
        print("    Target mode: spokenAudio")
        print("    Options: \(opts)")
        
        // Only reconfigure if needed (avoid conflicts with multiple instances)
        let needsConfig = session.category != .playback || 
                         session.mode != .spokenAudio ||
                         session.categoryOptions != opts
        
        if needsConfig {
            print("    Reconfiguring audio session...")
            // Use .playback category to enable background audio and lock screen controls
            // Mode .spokenAudio is better for language learning content
            do {
                try session.setCategory(.playback, mode: .spokenAudio, options: opts)
                print("    ✅ Audio session category and mode set")
            } catch {
                print("    ❌ Failed to set audio session category: \(error)")
                print("    Attempting fallback configuration without mode...")
                // Fallback: try without specifying mode
                do {
                    try session.setCategory(.playback, options: opts)
                    print("    ✅ Audio session category set (without mode)")
                } catch {
                    print("    ❌ Fallback also failed: \(error)")
                    // Last resort: try minimal configuration
                    print("    Attempting minimal configuration...")
                    try session.setCategory(.playback)
                    print("    ✅ Audio session set to playback (minimal)")
                }
            }
        } else {
            print("    Audio session already configured correctly")
        }
        
        // Activate session with option to not interrupt other audio if already active
        if !session.isOtherAudioPlaying {
            print("    Activating audio session...")
            do {
                try session.setActive(true, options: [])
                print("    ✅ Audio session activated")
            } catch {
                print("    ❌ Failed to activate audio session: \(error)")
                throw error
            }
        } else {
            print("    Skipping activation (other audio is playing)")
        }
    }

    private func resolveURL(for track: Track) -> URL? {
        let filename = track.filename
        let ext = (filename as NSString).pathExtension
        let base = (filename as NSString).deletingPathExtension
        
        print("  🔍 [AudioPlayerServiceAVPlayer] Resolving URL for: \(filename)")
        print("    Base: \(base)")
        print("    Extension: \(ext)")

        // 1) Bundle
        print("    Checking Bundle...")
        if !base.isEmpty, let u = Bundle.main.url(forResource: base, withExtension: ext.isEmpty ? nil : ext) {
            print("    ✅ Found in Bundle: \(u.path)")
            return u
        }
        print("    ❌ Not found in Bundle")

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

            print("    Checking Documents/LanguageMirror path: \(inTrackDir.path)")
            if FileManager.default.fileExists(atPath: inTrackDir.path) {
                print("    ✅ Found in Documents/LanguageMirror: \(inTrackDir.path)")
                return inTrackDir
            }
            print("    ❌ Not found in Documents/LanguageMirror")

            // 3) Documents root fallback
            let inDocs = docs.appendingPathComponent(filename)
            print("    Checking Documents root: \(inDocs.path)")
            if FileManager.default.fileExists(atPath: inDocs.path) {
                print("    ✅ Found in Documents root: \(inDocs.path)")
                return inDocs
            }
            print("    ❌ Not found in Documents root")
        }

        print("    ❌ File not found in any location")
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
