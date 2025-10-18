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
    func listNonEmptyPacks() -> [Pack]
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

    // Practice Sets
    func listPracticeSets(in trackId: String) -> [PracticeSet]
    func loadPracticeSet(id: String) throws -> PracticeSet
    func addPracticeSet(_ practiceSet: PracticeSet, to trackId: String) throws
    func updatePracticeSet(_ practiceSet: PracticeSet, in trackId: String) throws
    func deletePracticeSet(id: String, from trackId: String) throws

    // Clips
    func listClips(in practiceSetId: String) -> [Clip]
    func loadClip(id: String) throws -> Clip
    func addClip(_ clip: Clip, to practiceSetId: String) throws
    func updateClip(_ clip: Clip, in practiceSetId: String) throws
    func deleteClip(id: String, from practiceSetId: String) throws
}
