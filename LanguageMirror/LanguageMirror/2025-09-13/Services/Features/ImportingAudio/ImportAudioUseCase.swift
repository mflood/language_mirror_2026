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

        // Use DNS namespace for deterministic UUID generation
        let dnsNamespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")! // DNS namespace
        let packUUID = uuid5(namespace: dnsNamespace, name: norm("Downloaded Audio"))

        // 1) Let the engine validate / prep the URL
        let prepared = try await engine.prepareLocalAudio(from: sourceURL)
        try Task.checkCancellation()

        // 2) Persist to library
        //  id is UUID5 of the source URL
        let id = uuid5(namespace: dnsNamespace, name: norm(sourceURL.absoluteString)).uuidString
        
        let ext = prepared.pathExtension.isEmpty ? "m4a" : prepared.pathExtension
        let filename = "audio.\(ext)"
        guard let lib = library as? LibraryServiceJSON else { throw LibraryError.writeFailed }

        let folder = lib.trackFolder(forPackId: packUUID.uuidString, forTrackId: id)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let dest = folder.appendingPathComponent(filename)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }

        try Task.checkCancellation()
        try fm.copyItem(at: prepared, to: dest)

        // 3) Duration via async load (iOS 18)
        let seconds = try await AVAsset(url: dest).load(.duration).seconds
        let ms = Int((seconds.isFinite ? seconds : 0) * 1000.0)

        let title = suggestedTitle ?? prepared.deletingPathExtension().lastPathComponent
        // let track = Track(id: id, title: title, filename: filename, durationMs: ms)
        //try library.addTrack(track)
        return []
    }
}
