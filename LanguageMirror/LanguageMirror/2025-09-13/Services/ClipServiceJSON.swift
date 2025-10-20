//
//  ClipServiceJSON.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//

// path: Services/ClipServiceJSON.swift
import Foundation

final class ClipServiceJSON: ClipService {
    
    private let fm = FileManager.default

    func loadMap(for trackId: String) throws -> PracticeSet {
        let url = mapURL(trackId: trackId)
        if !fm.fileExists(atPath: url.path) {
            let emptyMap = PracticeSet.fullTrackFactory(trackId: trackId, displayOrder: 0)
            try persist(emptyMap, to: url)
            return emptyMap
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(PracticeSet.self, from: data)
        } catch let e as DecodingError {
            throw ClipStoreError.decode(e)
        } catch {
            throw ClipStoreError.io(error)
        }
    }

    func saveMap(_ map: PracticeSet, for trackId: String) throws {
        try persist(map, to: mapURL(trackId: trackId))
    }

    func add(_ clip: Clip, to trackId: String) throws -> PracticeSet {
        guard clip.startMs >= 0, clip.endMs > clip.startMs else { throw ClipStoreError.invalidRange }
        var map = try loadMap(for: trackId)
        map.clips.append(clip)
        // Keep chronological order by default; user can override via reorder
        map.clips.sort { $0.startMs < $1.startMs }
        try saveMap(map, for: trackId)
        return map
    }

    func delete(clipId: String, from trackId: String) throws -> PracticeSet {
        var map = try loadMap(for: trackId)
        let before = map.clips.count
        map.clips.removeAll { $0.id == clipId }
        guard map.clips.count != before else { throw ClipStoreError.notFound }
        try saveMap(map, for: trackId)
        return map
    }

    func update(_ clip: Clip, in trackId: String) throws -> PracticeSet {
        guard clip.startMs >= 0, clip.endMs > clip.startMs else { throw ClipStoreError.invalidRange }
        var map = try loadMap(for: trackId)
        guard let idx = map.clips.firstIndex(where: { $0.id == clip.id }) else {
            throw ClipStoreError.notFound
        }
        map.clips[idx] = clip
        map.clips.sort { $0.startMs < $1.startMs }
        try saveMap(map, for: trackId)
        return map
    }

    func moveClip(from sourceIndex: Int, to destinationIndex: Int, in trackId: String) throws -> PracticeSet {
        var map = try loadMap(for: trackId)
        guard map.clips.indices.contains(sourceIndex),
              map.clips.indices.contains(destinationIndex) else { return map }
        let item = map.clips.remove(at: sourceIndex)
        map.clips.insert(item, at: destinationIndex)
        // Note: we honor user-defined ordering here (no auto-sort)
        try saveMap(map, for: trackId)
        return map
    }
    
    // MARK: - Clip Editing
    
    func splitClip(id: String, atMs: Int, in trackId: String) throws -> (Clip, Clip) {
        var map = try loadMap(for: trackId)
        
        guard let idx = map.clips.firstIndex(where: { $0.id == id }) else {
            throw ClipStoreError.notFound
        }
        
        let originalClip = map.clips[idx]
        
        // Validate split point
        guard atMs > originalClip.startMs + 500,
              atMs < originalClip.endMs - 500 else {
            throw ClipStoreError.invalidRange
        }
        
        // Create first clip (modified original)
        let clip1 = Clip(
            id: originalClip.id,
            startMs: originalClip.startMs,
            endMs: atMs,
            kind: originalClip.kind,
            title: originalClip.title,
            repeats: originalClip.repeats,
            startSpeed: originalClip.startSpeed,
            endSpeed: originalClip.endSpeed,
            languageCode: originalClip.languageCode
        )
        
        // Create second clip (new ID, rest copied from original)
        let clip2 = Clip(
            id: UUID().uuidString,
            startMs: atMs,
            endMs: originalClip.endMs,
            kind: originalClip.kind,
            title: originalClip.title,
            repeats: originalClip.repeats,
            startSpeed: originalClip.startSpeed,
            endSpeed: originalClip.endSpeed,
            languageCode: originalClip.languageCode
        )
        
        // Replace original with clip1 and insert clip2 after
        map.clips[idx] = clip1
        map.clips.insert(clip2, at: idx + 1)
        
        try saveMap(map, for: trackId)
        
        return (clip1, clip2)
    }
    
    func mergeClips(clipId: String, into previousClipId: String, in trackId: String) throws -> Clip {
        var map = try loadMap(for: trackId)
        
        guard let currentIdx = map.clips.firstIndex(where: { $0.id == clipId }),
              let prevIdx = map.clips.firstIndex(where: { $0.id == previousClipId }),
              prevIdx < currentIdx else {
            throw ClipStoreError.notFound
        }
        
        let currentClip = map.clips[currentIdx]
        var previousClip = map.clips[prevIdx]
        
        // Merge: extend previous clip to end of current clip
        previousClip.endMs = currentClip.endMs
        
        // Update previous clip and remove current clip
        map.clips[prevIdx] = previousClip
        map.clips.remove(at: currentIdx)
        
        try saveMap(map, for: trackId)
        
        return previousClip
    }
    
    func updateClipKind(id: String, kind: ClipKind, in trackId: String) throws {
        var map = try loadMap(for: trackId)
        
        guard let idx = map.clips.firstIndex(where: { $0.id == id }) else {
            throw ClipStoreError.notFound
        }
        
        var clip = map.clips[idx]
        clip.kind = kind
        map.clips[idx] = clip
        
        try saveMap(map, for: trackId)
    }

    // MARK: - Helpers

    private func mapURL(trackId: String) -> URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs
            .appendingPathComponent("LanguageMirror", isDirectory: true)
            .appendingPathComponent("library", isDirectory: true)
            .appendingPathComponent("tracks", isDirectory: true)
            .appendingPathComponent(trackId, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("track.json")
    }

    private func persist(_ map: PracticeSet, to url: URL) throws {
        do {
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(map)
            try data.write(to: url, options: .atomic)
        } catch let e as EncodingError {
            throw ClipStoreError.encode(e)
        } catch {
            throw ClipStoreError.io(error)
        }
    }
}



