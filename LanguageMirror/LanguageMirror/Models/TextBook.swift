//
//  Book.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//


import Foundation

struct Textbook: Hashable, Codable {
    let id: UUID
    var title: String
    var chapters: [Chapter]
}

struct Chapter: Hashable, Codable {
    let id: UUID
    var title: String
    var tracks: [AudioTrack]
}
