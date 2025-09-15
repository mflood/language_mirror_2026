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
    var languageCode: String?    // e.g., "ko-KR" or "en-US"
}

struct SegmentMap: Codable, Equatable {
    var version: Int
    var segments: [Segment]
}

enum SegmentKind: String, Codable { case drill, skip, noise }

struct Segment: Codable, Identifiable, Equatable {
    let id: String
    var startMs: Int
    var endMs: Int
    var kind: SegmentKind
    var title: String?
    var repeats: Int?               // nil = use global N
    var languageCode: String?
    var transcript: [TranscriptSpan]?
}

struct TranscriptSpan: Codable, Equatable {
    var startMs: Int
    var endMs: Int
    var text: String
    var speaker: String?
}

