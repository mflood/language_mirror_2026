//
//  ClipService.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//

// path: Services/ClipService.swift
import Foundation

protocol ClipService {
    func loadMap(for trackId: String) throws -> PracticeSet
    func saveMap(_ map: PracticeSet, for trackId: String) throws
    func add(_ clip: Clip, to trackId: String) throws -> PracticeSet
    func delete(clipId: String, from trackId: String) throws -> PracticeSet

    // NEW:
    func update(_ clip: Clip, in trackId: String) throws -> PracticeSet
    func moveClip(from sourceIndex: Int, to destinationIndex: Int, in trackId: String) throws -> PracticeSet
}

enum ClipStoreError: Error, LocalizedError {
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
        case .notFound: return "Clip not found"
        case .invalidRange: return "Invalid time range"
        }
    }
}


// path: Services/ClipService.swift
extension ClipService {
    /// Save/replace the whole map (used by bundle imports)
    func replaceMap(_ map: PracticeSet, for trackId: String) throws -> PracticeSet {
        let _ = try saveMap(map, for: trackId) // reuse your existing writer
        return map
    }
}

