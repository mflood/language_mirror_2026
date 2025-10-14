//
//  ImportVideoUseCase.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingVideo/ImportVideoUseCase.swift
@preconcurrency import AVFoundation
import Foundation

public final class ImportVideoUseCase {
    
    private let engine: VideoImporting
    private let fm = FileManager.default
    private let library: LibraryService

    init(engine: VideoImporting, library: LibraryService) {
        self.engine = engine
        self.library = library
    }

    func run(videoURL: URL, suggestedTitle: String?) async throws -> [Track] {
        try Task.checkCancellation()

        // 1) Extract audio using the pluggable engine
        let audioTemp = try await engine.extractAudio(from: videoURL)
        
        // 2) Persist into library (same as your previous copy logic)
        let trackId = UUID().uuidString
        
        let ext = audioTemp.pathExtension.isEmpty ? "m4a" : audioTemp.pathExtension
        let filename = "audio.\(ext)"
        guard let lib = library as? LibraryServiceJSON else { throw LibraryError.writeFailed }

        let folder = lib.trackFolder(forPackId: UUID.namespaceFromVideo.uuidString, forTrackId: trackId)
        
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let dest = folder.appendingPathComponent(filename)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.copyItem(at: audioTemp, to: dest)

        // 3) Compute duration (async load in iOS 18)
        let duration = try await AVURLAsset(url: dest).load(.duration).seconds
        let durationMs = Int((duration.isFinite ? duration : 0) * 1000.0)

        let title = suggestedTitle ?? videoURL.deletingPathExtension().lastPathComponent
        
        let track = Track(
            id: trackId,
            packId: UUID.namespaceFromVideo.uuidString,
            title: title,
            filename: filename,
            localUrl: dest,
            durationMs: durationMs,
            segmentMaps: [SegmentMap.fullTrackFactory(trackId: trackId, displayOrder: 0)],
            transcripts: [],
            // createdAt: Date(),
        )
        try library.addTrack(track)
        return [track]
    }
}
