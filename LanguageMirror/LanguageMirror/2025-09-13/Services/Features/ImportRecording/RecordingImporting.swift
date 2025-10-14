//
//  RecordingImporting.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingRecording/RecordingImporting.swift
import Foundation

public protocol RecordingImporting: Sendable {
    /// Validates/prepares a recently recorded local audio file.
    /// Returns a readable local URL to persist into the library.
    func prepareRecordedAudio(from url: URL) async throws -> URL
}
