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

    func run(videoURL: URL, suggestedTitle: String?, progress: (@Sendable (Float) -> Void)?) async throws -> [Track] {
        try Task.checkCancellation()

        // 1) Extract audio using the pluggable engine
        let audioTempUrl = try await engine.extractAudio(from: videoURL, progress: progress)
        
        // 2) Generate deterministic IDs
        let trackId = generateTrackId(from: videoURL)
        let packId = UUID.namespaceFromVideo.uuidString
        
        // 3) Persist audio to library storage
        let (audioLibraryUrl, filename) = try await persistAudio(audioTempUrl, trackId: trackId, packId: packId)
        
        // 4) Calculate duration
        let durationMs = try await calculateDuration(of: audioLibraryUrl)
        
        // 5) Create track and add to library
        let track = buildTrack(
            id: trackId,
            packId: packId,
            audioURL: audioLibraryUrl,
            filename: filename,
            durationMs: durationMs,
            suggestedTitle: suggestedTitle
        )
        
        try library.addTrack(track, to: packId)
        return [track]
    }
    
    // MARK: - Helper Methods
    
    private func generateTrackId(from videoURL: URL) -> String {
        return uuid5(namespace: UUID.namespaceFromVideo, name: norm(videoURL.absoluteString)).uuidString
    }
    
    private func persistAudio(_ audioURL: URL, trackId: String, packId: String) async throws -> (url: URL, filename: String) {
        guard let lib = library as? LibraryServiceJSON else {
            throw LibraryError.writeFailed
        }
        
        let folder = lib.trackFolder(forPackId: packId, forTrackId: trackId)
        let ext = audioURL.pathExtension.isEmpty ? "m4a" : audioURL.pathExtension
        let filename = "audio.\(ext)"
        let audioLibraryUrl = folder.appendingPathComponent(filename)

        // Create folders and persist audio file
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        if fm.fileExists(atPath: audioLibraryUrl.path) { try fm.removeItem(at: audioLibraryUrl) }
        try fm.copyItem(at: audioURL, to: audioLibraryUrl)
        
        return (audioLibraryUrl, filename)
    }
    
    private func calculateDuration(of audioURL: URL) async throws -> Int {
        let duration = try await AVURLAsset(url: audioURL).load(.duration).seconds
        return Int((duration.isFinite ? duration : 0) * 1000.0)
    }
    
    private func buildTrack(id: String, packId: String, audioURL: URL, filename: String, durationMs: Int, suggestedTitle: String?) -> Track {
        let title = suggestedTitle ?? audioURL.deletingPathExtension().lastPathComponent
        let ext = audioURL.pathExtension.isEmpty ? "m4a" : audioURL.pathExtension
        let tags = autoTagsForTrack(sourceType: .videoExtract, languageCode: nil, fileExtension: ext)
        
        return Track(
            id: id,
            packId: packId,
            title: title,
            filename: filename,
            localUrl: audioURL,
            durationMs: durationMs,
            languageCode: nil,
            practiceSets: [PracticeSet.fullTrackFactory(trackId: id, displayOrder: 0)],
            transcripts: [],
            tags: tags,
            sourceType: .videoExtract,
            createdAt: Date()
        )
    }
}
