//
//  Models.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import Foundation

struct Pack: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var languageHint: String?
    var tracks: [Track]
}

struct Track: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var filename: String         // e.g., "sample.mp3"
    var durationMs: Int?         // optional for now
}
