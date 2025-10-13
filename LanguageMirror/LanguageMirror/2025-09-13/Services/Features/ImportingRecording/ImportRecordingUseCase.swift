//
//  ImportRecordingUseCase.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingRecording/ImportRecordingUseCase.swift
@preconcurrency import AVFoundation
import Foundation

public final class ImportRecordingUseCase {
    private let engine: RecordingImporting
    private let fm = FileManager.default
    private let library: LibraryService

    init(engine: RecordingImporting, library: LibraryService) {
        self.engine = engine
        self.library = library
    }

    /// `title` lets you name recordings like "Recording 2025-09-20, 10:15".
    func run(sourceURL: URL, title: String) async throws -> [Track] {
        try Task.checkCancellation()

        // 1) Validate/prep the recorded URL
        let prepared = try await engine.prepareRecordedAudio(from: sourceURL)
        try Task.checkCancellation()
        
        // 2) Persist to library
        let id = uuid5(namespace: UUID.namespaceFromRecording, name: norm(title)).uuidString
        
        let ext = prepared.pathExtension.isEmpty ? "m4a" : prepared.pathExtension
        let filename = "audio.\(ext)"

        guard let lib = library as? LibraryServiceJSON else { throw LibraryError.writeFailed }
        let folder = lib.trackFolder(forPackId: UUID.namespaceFromRecording.uuidString, forTrackId: id)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let dest = folder.appendingPathComponent(filename)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }

        try Task.checkCancellation()
        try fm.copyItem(at: prepared, to: dest)

        // 3) Duration (iOS 18 async load)
        let seconds = try await AVURLAsset(url: dest).load(.duration).seconds
        let ms = Int((seconds.isFinite ? seconds : 0) * 1000.0)

        // let track = Track(id: id, packId: nil, title: title, filename: filename, durationMs: ms)
        // try library.addTrack(track)
        return []
    }
}
