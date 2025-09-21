//
//  ImportSampleUseCase.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingSample/ImportSampleUseCase.swift
@preconcurrency import AVFoundation
import Foundation

public final class ImportSampleUseCase {
    private let engine: SampleImporting
    private let library: LibraryService
    private let segments: SegmentService
    private let fm = FileManager.default

    init(engine: SampleImporting, library: LibraryService, segments: SegmentService) {
        self.engine = engine
        self.library = library
        self.segments = segments
    }

    func run() async throws -> [Track] {
        try Task.checkCancellation()

        // 1) Locate embedded assets
        let (audioURL, manifestURL) = try await engine.loadEmbeddedSample()

        // 2) Persist into library
        let id = UUID().uuidString
        guard let lib = library as? LibraryServiceJSON else { throw LibraryError.writeFailed }
        let folder = lib.trackFolder(for: id)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        let filename = "sample.\(audioURL.pathExtension.isEmpty ? "mp3" : audioURL.pathExtension)"
        let dest = folder.appendingPathComponent(filename)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.copyItem(at: audioURL, to: dest)

        // 3) Duration (iOS 18 async load)
        let dur = try await AVAsset(url: dest).load(.duration).seconds
        let ms = Int((dur.isFinite ? dur : 0) * 1000.0)

        var track = Track(id: id, title: "Sample Track", filename: filename, durationMs: ms)
        try library.addTrack(track)

        // 4) Optional segments via manifest (same shape you already used)
        if let murl = manifestURL,
           let data = try? Data(contentsOf: murl),
           let mf = try? JSONDecoder().decode(BundleManifest.self, from: data),
           let seg = mf.tracks.first?.segments {
            _ = try? segments.replaceMap(seg, for: track.id)
            // Reload canonical copy if your library mutates on update
            if let reloaded = try? library.loadTrack(id: track.id) { track = reloaded }
        }

        return [track]
    }
}
