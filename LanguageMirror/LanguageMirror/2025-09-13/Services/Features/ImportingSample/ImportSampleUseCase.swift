//
//  ImportSampleUseCase.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingSample/ImportSampleUseCase.swift
@preconcurrency import AVFoundation
import Foundation

final class ImportSampleUseCase {
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
        
        guard let lib = library as? LibraryServiceJSON else {
            throw LibraryError.writeFailed
        }
        
        // 1) Locate embedded assets
        let embeddedBundleManifest = try await engine.loadEmbeddedSample()

        var return_tracks: [Track] = []
        
        for bundlePack in embeddedBundleManifest.packs {
            
            let packId = UUID().uuidString
            var tracks: [Track] = []
            for bundleTrack in bundlePack.tracks {
                
                let (name, ext) = bundleTrack.splitFilename()
                
                guard let audioUrl = Bundle.main.url(forResource: name, withExtension: ext) else {
                    throw SampleImportError.notFound
                }
                
                // 2) Persist into library
                let id = UUID().uuidString
                let folder = lib.trackFolder(for: id)
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                
                let dest = folder.appendingPathComponent(bundleTrack.filename)
        
                // 3) Duration (iOS 18 async load)
                let dur = try await AVURLAsset(url: audioUrl).load(.duration).seconds
                let ms = Int((dur.isFinite ? dur : 0) * 1000.0)
                
                var track = Track(id: id, packId: packId, title: "Sample Track", filename: bundleTrack.filename,
                                  localUrl: audioUrl, durationMs: ms, languageCode: nil, segmentMaps: [], transcripts: [])
                
                do {
                    try library.addTrack(track)
                    tracks.append(track)
                    return_tracks.append(track)
                } catch {
                    print("Failed to add track to library: \(error)")
                }
                
                let pack = Pack(id: packId, title: bundlePack.title, tracks: tracks)
                
            }
        }
        return return_tracks
    }
}
