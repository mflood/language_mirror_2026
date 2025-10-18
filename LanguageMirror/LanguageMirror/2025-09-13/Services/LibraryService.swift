//
//  LibraryService.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import Foundation

enum LibraryError: Error {
    case notFound
    case writeFailed
    case ioError(Error)
    case decodeError(Error)
    case encodeError(Error)
}

protocol LibraryService {
    // Packs
    func listPacks() -> [Pack]
    func loadPack(id: String) throws -> Pack
    func addPack(_ pack: Pack) throws
    func updatePack(_ pack: Pack) throws

    // Pack Tracks
    func listTracks(in packId: String) -> [Track]
    func addTrack(_ track: Track, to packId: String) throws

    // Tracks
    func listTracks(in group: String?) -> [Track]
    func loadTrack(id: String) throws -> Track           
    func updateTrack(_ track: Track) throws

    // Arrangements
    func listArrangements(in trackId: String) -> [Arrangement]
    func loadArrangement(id: String) throws -> Arrangement
    func addArrangement(_ arrangement: Arrangement, to trackId: String) throws
    func updateArrangement(_ arrangement: Arrangement, in trackId: String) throws
    func deleteArrangement(id: String, from trackId: String) throws

    // Segments
    func listSegments(in arrangementId: String) -> [Segment]
    func loadSegment(id: String) throws -> Segment
    func addSegment(_ segment: Segment, to arrangementId: String) throws
    func updateSegment(_ segment: Segment, in arrangementId: String) throws
    func deleteSegment(id: String, from arrangementId: String) throws
}

enum LibraryError: Error {
    case notFound
    case writeFailed
    case ioError(Error)
    case decodeError(Error)
    case encodeError(Error)
}
