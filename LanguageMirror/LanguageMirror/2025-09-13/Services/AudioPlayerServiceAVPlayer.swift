//
//  AudioPlayerServiceAVPlayer.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//
// path: Services/AudioPlayerServiceAVPlayer.swift
// path: Services/AudioPlayerServiceAVPlayer.swift
import Foundation
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

    // Segment mode
    private var currentTrack: Track?
    private var trackURL: URL?
    private var segmentsQueue: [Segment] = []
    private var currentSegmentIndex: Int = 0
    private var currentSegmentRepeatsRemaining: Int = 0
    private var globalRepeats: Int = 1
    private var gapSeconds: TimeInterval = 0.5
    private var interSegmentGapSeconds: TimeInterval = 0.5
    private var prerollSeconds: TimeInterval = 0.0
    private var currentSegmentStart: CMTime = .zero
    private var currentSegmentEnd: CMTime = .zero
    private let pollInterval = CMTime(seconds: 0.01, preferredTimescale: 600) // 10ms
    private let epsilon: Double = 0.005 // 5ms

    
    // MARK: - Media Player
    
    // Remote command / now playing
    private var nowPlayingInfo: [String: Any] = [:]
    
    // Interruption state
    private var shouldResumeAfterInterruption = false
    
    // MARK: - Public API

    func play(track: Track, repeats: Int, gapSeconds: TimeInterval) throws {
        // Whole-track convenience (legacy)
        try startWholeTrack(track: track, repeats: repeats, gap: gapSeconds)
    }

    func play(track: Track,
              segments: [Segment],
              globalRepeats: Int,
              gapSeconds: TimeInterval,
              interSegmentGapSeconds: TimeInterval,
              prerollMs: Int) throws {
        try startSegments(track: track,
                          segments: segments,
                          globalRepeats: globalRepeats,
                          gap: gapSeconds,
                          interGap: interSegmentGapSeconds,
                          prerollMs: prerollMs)
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
        segmentsQueue = []
        currentTrack = nil
        trackURL = nil

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

    // MARK: - Segment mode

    private func startSegments(track: Track,
                               segments: [Segment],
                               globalRepeats: Int,
                               gap: TimeInterval,
                               interGap: TimeInterval,
                               prerollMs: Int) throws {
        stop() // cleanup

        guard let url = resolveURL(for: track) else {
            throw AudioPlayerError.fileNotFound(filename: track.filename)
        }
        try configureSession()

        currentTrack = track
        trackURL = url
        segmentsQueue = segments
        self.globalRepeats = max(1, globalRepeats)
        self.gapSeconds = max(0, gap)
        self.interSegmentGapSeconds = max(0, interGap)
        self.prerollSeconds = max(0, Double(prerollMs) / 1000.0)
        currentSegmentIndex = 0

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)

        // Periodic observer to detect end-of-segment
        addPeriodicObserver()

        addSessionNotifications()                   // Media Player
        setupRemoteCommands()                       // Media Player
        
        // Start first segment
        startCurrentSegment()
    }

    private func startCurrentSegment() {
        guard currentSegmentIndex >= 0, currentSegmentIndex < segmentsQueue.count else {
            stop()
            return
        }
        guard let player = player, let track = currentTrack else {
            stop(); return
        }

        let seg = segmentsQueue[currentSegmentIndex]
        currentSegmentRepeatsRemaining = max(1, seg.repeats ?? globalRepeats)

        currentSegmentStart = CMTime(seconds: Double(seg.startMs) / 1000.0, preferredTimescale: 600)
        currentSegmentEnd   = CMTime(seconds: Double(seg.endMs)   / 1000.0, preferredTimescale: 600)

        let seekStart = max(0, currentSegmentStart.seconds - prerollSeconds)
        let seekTime = CMTime(seconds: seekStart, preferredTimescale: 600)
        
        // Seek precisely to start and play
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self else { return }
            self.player?.play()
            self.isPlaying = true
            
            // Update Now Playing for this segment (duration is segment length)
            let segDuration = self.currentSegmentEnd.seconds - self.currentSegmentStart.seconds // Media Player
            self.updateNowPlaying(track: track,
                                  segmentTitle: seg.title,
                                  elapsed: 0,
                                  duration: max(0.01, segDuration),
                                  rate: 1.0) // Media Player
            
            NotificationCenter.default.post(name: .AudioPlayerDidStart, object: nil)
        }
    }

    private func handleSegmentTick(_ time: CMTime) {
        // End-of-segment detection
        guard isPlaying else { return }
        
        // Update elapsed in Now Playing (ignoring preroll; shows progress of the actual segment)
        let elapsed = max(0, time.seconds - currentSegmentStart.seconds)
        updateNowPlayingElapsed(elapsed)
        
        if time.seconds >= currentSegmentEnd.seconds - epsilon {
            // Stop immediately to avoid hearing audio past end
            player?.pause()
            isPlaying = false

            currentSegmentRepeatsRemaining -= 1
            if currentSegmentRepeatsRemaining > 0 {
                // repeat same segment after gap
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }

                    let seekStart = max(0, self.currentSegmentStart.seconds - self.prerollSeconds)
                    let seekTime = CMTime(seconds: seekStart, preferredTimescale: 600)

                    self.player?.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                        self.player?.play()
                        self.isPlaying = true
                        // reset elapsed for new loop
                        self.updateNowPlayingElapsed(0)
                        NotificationCenter.default.post(name: .AudioPlayerDidStart, object: nil)
                    }
                }
                pendingWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + gapSeconds, execute: work)
            } else {
                // advance to next segment after inter-segment gap
                currentSegmentIndex += 1
                let work = DispatchWorkItem { [weak self] in
                    self?.startCurrentSegment()
                }
                pendingWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + interSegmentGapSeconds, execute: work)
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
        
        // Media Player
        // If you later surface a UI switch, read a `duck = <from settings>` here
        let duck = (AppContainer().settings.duckOthers) // safe default usage if container exists
        var opts: AVAudioSession.CategoryOptions = [.mixWithOthers, .allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
        if duck { opts.insert(.duckOthers) }
        
        
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
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

        // 2) Documents/LanguageMirror/library/tracks/<track.id>/<filename>
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let inTrackDir = docs
                .appendingPathComponent("LanguageMirror", isDirectory: true)
                .appendingPathComponent("library", isDirectory: true)
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

        let t1 = center.playCommand.addTarget { [weak self] _ in self?.resume(); return .success }
        let t2 = center.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        let t3 = center.stopCommand.addTarget { [weak self] _ in self?.stop(); return .success }

        // (Optional) Next/Previous as segment skip:
        // center.nextTrackCommand.isEnabled = true
        // center.previousTrackCommand.isEnabled = true
        // let t4 = center.nextTrackCommand.addTarget { [weak self] _ in self?.skipToNextSegment(); return .success }
        // let t5 = center.previousTrackCommand.addTarget { [weak self] _ in self?.skipToPreviousSegment(); return .success }

        center.playCommand.addTarget { [weak self] _ in self?.resume(); return .success }
        center.pauseCommand.addTarget { [weak self] _ in self?.pause();  return .success }
        center.stopCommand.addTarget  { [weak self] _ in self?.stop();   return .success }

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
        var info: [String: Any] = nowPlayingInfo
        info[MPMediaItemPropertyTitle] = segmentTitle?.isEmpty == false ? segmentTitle : track.title
        info[MPMediaItemPropertyAlbumTitle] = "LanguageMirror"
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        // If you have artwork later, set MPMediaItemPropertyArtwork here.

        nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
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

    // (Optional) segment skip for remote next/prev:
    // private func skipToNextSegment() { currentSegmentIndex = min(currentSegmentIndex+1, segmentsQueue.count); startCurrentSegment() }
    // private func skipToPreviousSegment() { currentSegmentIndex = max(0, currentSegmentIndex-1); startCurrentSegment() }



}
