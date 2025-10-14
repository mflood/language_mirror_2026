//
//  VideoImporting.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingVideo/VideoImporting.swift
import Foundation

public protocol VideoImporting: Sendable {
    /// Extracts audio (m4a) from the given video URL and returns a temp audio file URL.
    func extractAudio(from videoURL: URL) async throws -> URL
}
