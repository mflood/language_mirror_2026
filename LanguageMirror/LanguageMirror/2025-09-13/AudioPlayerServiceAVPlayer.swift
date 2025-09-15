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

    func play(track: Track) throws {
        // Resolve URL: bundle → Documents/LanguageMirror/library/tracks/<id>/ → Documents root
        guard let url = resolveURL(for: track) else {
            throw AudioPlayerError.fileNotFound(filename: track.filename)
        }

        try configureSession()

        // Clean previous
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        player?.pause()

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)

        // Observe end to flip state back
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
        }

        player?.play()
        isPlaying = true
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
    }

    // MARK: - Helpers

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
                //.appendingPathComponent(filename, conformingTo: nil)

            if FileManager.default.fileExists(atPath: inTrackDir.path) {
                return inTrackDir
            }

            // 3) Documents root fallback
            //let inDocs = docs.appendingPathComponent(filename, conformingTo: nil)
            let inDocs = docs.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: inDocs.path) {
                return inDocs
            }
        }

        return nil
    }
}
