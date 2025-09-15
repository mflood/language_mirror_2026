//
//  SegmentService.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//

// path: Services/SegmentService.swift
import Foundation

protocol SegmentService {
    func loadMap(for trackId: String) throws -> SegmentMap
    func saveMap(_ map: SegmentMap, for trackId: String) throws
    func add(_ segment: Segment, to trackId: String) throws -> SegmentMap
    func delete(segmentId: String, from trackId: String) throws -> SegmentMap

    // NEW:
    func update(_ segment: Segment, in trackId: String) throws -> SegmentMap
    func moveSegment(from sourceIndex: Int, to destinationIndex: Int, in trackId: String) throws -> SegmentMap
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
