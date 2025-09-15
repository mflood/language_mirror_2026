//
//  AudioPlayerServiceAVPlayer.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//
// path: Services/AudioPlayerServiceAVPlayer.swift
import Foundation
import AVFoundation

final class AudioPlayerServiceAVPlayer: NSObject, AudioPlayerService {
    private var player: AVPlayer?
    private var endObserver: Any?
    private(set) var isPlaying: Bool = false

    private var pendingWorkItem: DispatchWorkItem?
    private var repeatsRemaining: Int = 0
    private var desiredRepeats: Int = 1
    private var gapSeconds: TimeInterval = 0.5
    private var currentTrack: Track?

    func play(track: Track, repeats: Int, gapSeconds: TimeInterval) throws {
        // Clean prior session first
        stop()

        guard let url = resolveURL(for: track) else {
            throw AudioPlayerError.fileNotFound(filename: track.filename)
        }
        try configureSession()

        desiredRepeats = max(1, repeats)
        repeatsRemaining = desiredRepeats
        self.gapSeconds = max(0, gapSeconds)
        currentTrack = track

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)

        // Observe completion to loop
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.repeatsRemaining -= 1
            if self.repeatsRemaining > 0 {
                // schedule next repeat after gap
                let work = DispatchWorkItem { [weak self] in
                    guard let self, let p = self.player else { return }
                    p.seek(to: .zero)
                    p.play()
                }
                self.pendingWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + self.gapSeconds, execute: work)
            } else {
                self.finish()
            }
        }

        player?.play()
        isPlaying = true
        NotificationCenter.default.post(name: .AudioPlayerDidStart, object: nil)
    }

    func pause() {
        guard isPlaying else { return }
        player?.pause()
        isPlaying = false
        // do NOT post DidStop; we’re paused
    }

    func resume() {
        guard !isPlaying else { return }
        player?.play()
        isPlaying = true
        NotificationCenter.default.post(name: .AudioPlayerDidStart, object: nil)
    }

    func stop() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        player?.pause()
        player = nil
        repeatsRemaining = 0
        currentTrack = nil

        if isPlaying {
            isPlaying = false
            NotificationCenter.default.post(name: .AudioPlayerDidStop, object: nil)
        }
    }

    // MARK: - Helpers

    private func finish() {
        // Called when repeats are exhausted
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
        NotificationCenter.default.post(name: .AudioPlayerDidStop, object: nil)
    }

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
