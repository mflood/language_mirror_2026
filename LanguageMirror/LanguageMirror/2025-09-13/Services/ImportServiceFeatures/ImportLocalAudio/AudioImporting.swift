//
//  AudioImporting.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingAudio/AudioImporting.swift
import Foundation

public protocol AudioImporting: Sendable {
    /// Validates / prepares a local audio URL selected via Files / Voice Memos.
    /// Returns a local (readable) URL to the audio file to be persisted.
    func prepareLocalAudio(from url: URL) async throws -> URL
}
