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
    func play(track: Track) throws
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

