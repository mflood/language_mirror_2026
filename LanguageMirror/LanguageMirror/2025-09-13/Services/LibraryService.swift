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
    func listTracks(in group: String?) -> [Track]
    func loadTrack(id: String) throws -> Track
    func addTrack(_ track: Track) throws            
    func updateTrack(_ track: Track) throws
}
