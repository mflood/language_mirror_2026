//
//  TrackMembership.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//


import Foundation


struct TrackMembership: Codable, Hashable {
    var collectionId: UUID
    var trackId: UUID
    var group: String? // e.g., "Chapter 1", or nil for unclassified
}
