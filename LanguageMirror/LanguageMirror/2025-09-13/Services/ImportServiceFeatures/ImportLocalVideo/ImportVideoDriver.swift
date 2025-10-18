//
//  ImportVideoDriver.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingVideo/ImportVideoDriver.swift
@preconcurrency import AVFoundation
import Foundation

public final class ImportVideoDriver {
    
    private let engine: VideoAudioExtractorProtocol
    private let fm = FileManager.default
    private let library: LibraryService

    init(engine: VideoAudioExtractorProtocol, library: LibraryService) {
        self.engine = engine
        self.library = library
    }

    func run(videoURL: URL, suggestedTitle: String?) async throws -> [Track] {
        try Task.checkCancellation()

        guard let lib = library as? LibraryServiceJSON else {
            throw LibraryError.writeFailed
        }
        
        // 1) Extract audio using the pluggable engine
        // let audioTempUrl = try await engine.extractAudio(from: videoURL)
        
        var audioTempUrl: URL
        do {
            audioTempUrl = try await engine.extractAudio(from: videoURL)
            print("Audio extracted to: \(audioTempUrl)")
        } catch {
            print("Failed to extract audio: \(error.localizedDescription)")
            throw error
        }
        
        // 2) Persist Audio Asset in File System
        
        // Determine Ids
        let trackId = UUID().uuidString
        let packId = UUID.namespaceFromVideo.uuidString
        
        // Determine folder, extension and filename
        let folder = lib.trackFolder(forPackId: packId, forTrackId: trackId)
        let ext = audioTempUrl.pathExtension.isEmpty ? "m4a" : audioTempUrl.pathExtension
        let filename = "audio.\(ext)"
        let audioLibraryUrl = folder.appendingPathComponent(filename)

        // Create folders and persist audio file
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        if fm.fileExists(atPath: audioLibraryUrl.path) { try fm.removeItem(at: audioLibraryUrl) }
        try fm.copyItem(at: audioTempUrl, to: audioLibraryUrl)

        // 3) Create Track and add to Library
        // Compute duration (async load in iOS 18)
        let duration = try await AVURLAsset(url: audioLibraryUrl).load(.duration).seconds
        let durationMs = Int((duration.isFinite ? duration : 0) * 1000.0)

        let title = suggestedTitle ?? videoURL.deletingPathExtension().lastPathComponent
        
        let track = Track(
            id: trackId,
            packId: packId,
            title: title,
            filename: filename,
            localUrl: audioLibraryUrl,
            durationMs: durationMs,
            arrangements: [Arrangement.fullTrackFactory(trackId: trackId, displayOrder: 0)],
            transcripts: [],
            tags: [],
            sourceType: .textbook
            // createdAt: Date(),
        )
        try library.addTrack(track)
        return [track]
    }
}
