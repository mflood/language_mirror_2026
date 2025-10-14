//
//  ImportAudioUseCase.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingAudio/ImportAudioUseCase.swift
@preconcurrency import AVFoundation
import Foundation

public final class ImportAudioUseCase {
    private let engine: AudioImporting
    private let fm = FileManager.default
    private let library: LibraryService

    init(engine: AudioImporting, library: LibraryService) {
        self.engine = engine
        self.library = library
    }

    func run(sourceURL: URL, suggestedTitle: String?) async throws -> [Track] {
        try Task.checkCancellation()

        // 1) Let the engine validate / prep the URL
        let prepared = try await engine.prepareLocalAudio(from: sourceURL)
        try Task.checkCancellation()

        // 2) Persist to library
        //  trackId is UUID5 of the source URL
        let trackId = uuid5(namespace: UUID.namespaceFromMemo, name: norm(sourceURL.absoluteString)).uuidString
        
        let ext = prepared.pathExtension.isEmpty ? "m4a" : prepared.pathExtension
        let filename = "audio.\(ext)"
        guard let lib = library as? LibraryServiceJSON else { throw LibraryError.writeFailed }

        let folder = lib.trackFolder(forPackId: UUID.namespaceFromMemo.uuidString, forTrackId: trackId)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let dest = folder.appendingPathComponent(filename)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }

        try Task.checkCancellation()
        try fm.copyItem(at: prepared, to: dest)

        // 3) Duration via async load (iOS 18)
        let seconds = try await AVURLAsset(url: dest).load(.duration).seconds
        let ms = Int((seconds.isFinite ? seconds : 0) * 1000.0)

        let title = suggestedTitle ?? prepared.deletingPathExtension().lastPathComponent
        
        let track = Track(
            id: trackId,
            packId: UUID.namespaceFromMemo.uuidString,
            title: title,
            filename: filename,
            localUrl: dest,
            durationMs: ms,
            segmentMaps: [SegmentMap.fullTrackFactory(trackId: trackId, displayOrder: 0)],
            transcripts: [],
            // createdAt: Date(),
        )
        try library.addTrack(track)
        return [track]
    }
}
