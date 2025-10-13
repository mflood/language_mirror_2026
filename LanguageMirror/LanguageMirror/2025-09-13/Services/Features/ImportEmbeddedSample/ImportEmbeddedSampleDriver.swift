//
//  ImportEmbeddedSampleDriver.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

@preconcurrency import AVFoundation
import Foundation

final class ImportEmbeddedSampleDriver {
    private let engine: EmbeddedBundleManifestLoader
    private let library: LibraryService
    private let segments: SegmentService
    private let fm = FileManager.default

    init(engine: EmbeddedBundleManifestLoader, library: LibraryService, segments: SegmentService) {
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
        
        // Use DNS namespace for deterministic UUID generation
        let embeddingNamespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")! // DNS namespace
        
        for bundlePack in embeddedBundleManifest.packs {
            
            let packUUID = uuid5(namespace: embeddingNamespace, name: norm(bundlePack.id))
            let packId = packUUID.uuidString
            
            var tracks: [Track] = []
            for bundleTrack in bundlePack.tracks {
                
                let (name, ext) = bundleTrack.splitFilename()
                
                guard let audioUrl = Bundle.main.url(forResource: name, withExtension: ext) else {
                    print("Skipping missing embedded asset: \(bundleTrack.filename)")
                    continue
                }
                                
                // 2) Duration (iOS 18 async load)
               
                var ms = bundleTrack.durationMs
                if ms == nil {
                    print("Reading file to get duration: \(bundleTrack.filename)")
                    let dur = try await AVURLAsset(url: audioUrl).load(.duration).seconds
                    let ms = Int((dur.isFinite ? dur : 0) * 1000.0)
                }
                
                // 3) Make track UUID
                let trackUUID = uuid5(namespace: packUUID, name: norm(bundleTrack.title + bundleTrack.filename))
                print("Track UUID: \(trackUUID) for \(bundleTrack.title)")
                let trackId = trackUUID.uuidString
                
                // Extract segment maps
                var trackSegmentMaps: [SegmentMap] = []
                
                for (idx, embeddedMap) in bundleTrack.segment_maps.enumerated() {
                    // Calculate deterministic UUID for segment map
                    let mapUUID = uuid5(namespace: trackUUID, name: norm(embeddedMap.title))
                    
                    print("Map UUID: \(mapUUID) for \(embeddedMap.title)")
                    
                    let map = SegmentMap(
                        id: mapUUID.uuidString,
                        trackId: trackId,
                        displayOrder: idx,
                        title: embeddedMap.title,
                        segments: embeddedMap.segments)
                    
                    trackSegmentMaps.append(map)
                }
                
                guard let lib = library as? LibraryServiceJSON else { throw LibraryError.writeFailed }
                let folder = lib.trackFolder(forPackId: packId, forTrackId: trackId)
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                
                let filename = "audio.\(audioUrl.pathExtension.isEmpty ? "mp3" : audioUrl.pathExtension)"
                
                print("Copying embedded asset to library: \(filename)")
                let dest = folder.appendingPathComponent(filename)
                print("Dest: \(dest.path)")
                if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                print("Copying \(audioUrl.path) to \(dest.path)")
                try fm.copyItem(at: audioUrl, to: dest)

             
                let track = Track(
                    id: trackId,
                    packId: packId,
                    title: bundleTrack.title,
                    filename: bundleTrack.filename,
                    localUrl: audioUrl,
                    durationMs: ms,
                    languageCode: nil,
                    segmentMaps: trackSegmentMaps,
                    transcripts: [])
                
                do {
                    try library.addTrack(track)
                    tracks.append(track)
                    return_tracks.append(track)
                } catch {
                    print("Failed to add track to library: \(error)")
                }
            }
        }
        return return_tracks
    }
}
