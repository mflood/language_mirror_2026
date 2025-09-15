//
//  LibraryService.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import Foundation

enum LibraryError: Error {
    case notFound
    case ioError(Error)
    case decodeError(Error)
    case encodeError(Error)
}

protocol LibraryService {
    func listPacks() -> [Pack]
    func listTracks(in packId: String?) -> [Track]
    func loadTrack(id: String) throws -> Track
    func saveTrack(_ track: Track) throws
}
