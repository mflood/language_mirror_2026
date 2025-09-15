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

        // Start first segment
        startCurrentSegment()
    }

    private func startCurrentSegment() {
        guard currentSegmentIndex >= 0, currentSegmentIndex < segmentsQueue.count else {
            stop()
            return
        }
        guard let player = player, let _ = trackURL else {
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
            NotificationCenter.default.post(name: .AudioPlayerDidStart, object: nil)
        }
    }

    private func handleSegmentTick(_ time: CMTime) {
        // End-of-segment detection
        guard isPlaying else { return }
        if time.seconds >= currentSegmentEnd.seconds - epsilon {
            // Stop immediately to avoid hearing audio past end
            player?.pause()
            isPlaying = false

            currentSegmentRepeatsRemaining -= 1
            if currentSegmentRepeatsRemaining > 0 {
                // repeat same segment after gap
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.player?.seek(to: self.currentSegmentStart, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                        self.player?.play()
                        self.isPlaying = true
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
    }

    // MARK: - Utilities

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
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
}
