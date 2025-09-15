//
//  SegmentServiceJSON.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//

// path: Services/SegmentServiceJSON.swift
import Foundation

final class SegmentServiceJSON: SegmentService {
    private let fm = FileManager.default

    func loadMap(for trackId: String) throws -> SegmentMap {
        let url = mapURL(trackId: trackId)
        if !fm.fileExists(atPath: url.path) {
            try persist(.empty, to: url)
            return .empty
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SegmentMap.self, from: data)
        } catch let e as DecodingError {
            throw SegmentStoreError.decode(e)
        } catch {
            throw SegmentStoreError.io(error)
        }
    }

    func saveMap(_ map: SegmentMap, for trackId: String) throws {
        try persist(map, to: mapURL(trackId: trackId))
    }

    func add(_ segment: Segment, to trackId: String) throws -> SegmentMap {
        guard segment.startMs >= 0, segment.endMs > segment.startMs else { throw SegmentStoreError.invalidRange }
        var map = try loadMap(for: trackId)
        map.segments.append(segment)
        // Keep chronological order by default; user can override via reorder
        map.segments.sort { $0.startMs < $1.startMs }
        try saveMap(map, for: trackId)
        return map
    }

    func delete(segmentId: String, from trackId: String) throws -> SegmentMap {
        var map = try loadMap(for: trackId)
        let before = map.segments.count
        map.segments.removeAll { $0.id == segmentId }
        guard map.segments.count != before else { throw SegmentStoreError.notFound }
        try saveMap(map, for: trackId)
        return map
    }

    func update(_ segment: Segment, in trackId: String) throws -> SegmentMap {
        guard segment.startMs >= 0, segment.endMs > segment.startMs else { throw SegmentStoreError.invalidRange }
        var map = try loadMap(for: trackId)
        guard let idx = map.segments.firstIndex(where: { $0.id == segment.id }) else {
            throw SegmentStoreError.notFound
        }
        map.segments[idx] = segment
        map.segments.sort { $0.startMs < $1.startMs }
        try saveMap(map, for: trackId)
        return map
    }

    func moveSegment(from sourceIndex: Int, to destinationIndex: Int, in trackId: String) throws -> SegmentMap {
        var map = try loadMap(for: trackId)
        guard map.segments.indices.contains(sourceIndex),
              map.segments.indices.contains(destinationIndex) else { return map }
        let item = map.segments.remove(at: sourceIndex)
        map.segments.insert(item, at: destinationIndex)
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

    private func persist(_ map: SegmentMap, to url: URL) throws {
        do {
            let data = try JSONEncoder().encode(map)
            try data.write(to: url, options: .atomic)
        } catch let e as EncodingError {
            throw SegmentStoreError.encode(e)
        } catch {
            throw SegmentStoreError.io(error)
        }
    }
}
