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



