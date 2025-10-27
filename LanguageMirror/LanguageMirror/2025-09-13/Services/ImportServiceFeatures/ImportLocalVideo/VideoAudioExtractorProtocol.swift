//
//  VideoAudioExtractorProtocol.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingVideo/VideoAudioExtractorProtocol.swift
import Foundation

public protocol VideoAudioExtractorProtocol: Sendable {
    /// Extracts audio (m4a) from the given video URL and returns a temp audio file URL.
    /// - Parameters:
    ///   - videoURL: The source video file URL
    ///   - progress: Optional callback for progress updates (0.0 to 1.0)
    func extractAudio(from videoURL: URL, progress: (@Sendable (Float) -> Void)?) async throws -> URL
}
