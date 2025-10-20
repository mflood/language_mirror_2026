//
//  AudioPlayerService.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//

// path: Services/AudioPlayerService.swift

import Foundation

protocol AudioPlayerService: AnyObject {
    var isPlaying: Bool { get }
    func play(track: Track, repeats: Int, gapSeconds: TimeInterval) throws
    
    /// Play only specific segments (typically .drill) in order.
    /// - Parameters:
    ///   - segments: Segments to play; segment.repeats overrides globalRepeats when present.
    ///   - globalRepeats: Fallback repeats if segment.repeats == nil (min 1).
    ///   - gapSeconds: Gap between repeats of the **same** segment (>= 0).
    ///   - interClipGapSeconds: Gap between **different** clips (>= 0).
    func play(track: Track,
              clips: [Clip],
              globalRepeats: Int,
              gapSeconds: TimeInterval,
              interClipGapSeconds: TimeInterval,
              prerollMs: Int) throws
    
    func pause()
    func resume()
    func stop()
}

enum AudioPlayerError: Error, LocalizedError {
    case fileNotFound(filename: String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let name): return "Audio file not found: \(name)"
        }
    }
}

// Convenience default (single play)
extension AudioPlayerService {
    func play(track: Track) throws {
        try play(track: track, repeats: 1, gapSeconds: 0)
    }
}

public extension Notification.Name {
    static let AudioPlayerDidStart = Notification.Name("AudioPlayerDidStart")
    static let AudioPlayerDidStop  = Notification.Name("AudioPlayerDidStop")
    static let AudioPlayerClipDidChange = Notification.Name("AudioPlayerClipDidChange")
    static let AudioPlayerLoopDidComplete = Notification.Name("AudioPlayerLoopDidComplete")
    static let AudioPlayerSpeedDidChange = Notification.Name("AudioPlayerSpeedDidChange")
    static let AudioPlayerDidUpdateTime = Notification.Name("AudioPlayerDidUpdateTime")
}
