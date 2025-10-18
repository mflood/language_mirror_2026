//
//  SegmentService.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//

// path: Services/SegmentService.swift
import Foundation

protocol SegmentService {
    func loadMap(for trackId: String) throws -> Arrangement
    func saveMap(_ map: Arrangement, for trackId: String) throws
    func add(_ segment: Segment, to trackId: String) throws -> Arrangement
    func delete(segmentId: String, from trackId: String) throws -> Arrangement

    // NEW:
    func update(_ segment: Segment, in trackId: String) throws -> Arrangement
    func moveSegment(from sourceIndex: Int, to destinationIndex: Int, in trackId: String) throws -> Arrangement
}

enum SegmentStoreError: Error, LocalizedError {
    case io(Error)
    case decode(Error)
    case encode(Error)
    case notFound
    case invalidRange

    var errorDescription: String? {
        switch self {
        case .io(let e): return "I/O error: \(e.localizedDescription)"
        case .decode(let e): return "Decode error: \(e.localizedDescription)"
        case .encode(let e): return "Encode error: \(e.localizedDescription)"
        case .notFound: return "Segment not found"
        case .invalidRange: return "Invalid time range"
        }
    }
}


// path: Services/SegmentService.swift
extension SegmentService {
    /// Save/replace the whole map (used by bundle imports)
    func replaceMap(_ map: Arrangement, for trackId: String) throws -> Arrangement {
        let _ = try saveMap(map, for: trackId) // reuse your existing writer
        return map
    }
}
