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
    // var createdAt: Date?      // Timestamp of when the track was imported
}

struct Track: Codable, Identifiable, Equatable {
    let id: String
    let packId: String
    var title: String
    var filename: String         // e.g., "sample.mp3"
    var localUrl: URL?     // local file URL if downloaded or imported
    var durationMs: Int?         // nice if you know it....
    var languageCode: String?    // e.g., "ko-KR" or "en-US"
    var segmentMaps: [SegmentMap] // Change to "Practice Sets" in UI
    var transcripts: [TranscriptSpan]
    // var createdAt: Date?      // Timestamp of when the track was imported
}

struct SegmentMap: Codable, Equatable {
    var id: String           // UUID string so we can reference it from practice sessions
    var trackId: String  // If we tag segments to play in a playlist, we can reference the track here
    var displayOrder: Int
    var title: String?
    var segments: [Segment]
    
    static func fullTrackFactory(trackId: String, displayOrder: Int) -> SegmentMap {
        return SegmentMap(
            id: UUID().uuidString,
            trackId: trackId,
            displayOrder: displayOrder,
            title: "Practice Set",
            segments: [
                Segment(id: UUID().uuidString, startMs: 0, endMs: 9999999, kind: .drill, title: "Full Track", repeats: nil, startSpeed: nil, endSpeed: nil)
            ]
        )
    }
}

enum SegmentKind: String, Codable, CaseIterable { case drill, skip, noise }

extension SegmentKind {
    var label: String {
        switch self {
        case .drill:  return "Drill"
        case .skip: return "Skip"
        case .noise: return "Noise"
        }
    }
}

struct Segment: Codable, Identifiable, Equatable {
    let id: String
    var startMs: Int
    var endMs: Int
    var kind: SegmentKind
    var title: String?
    var repeats: Int?            // nil = use global N
    var startSpeed: Float?       // nil = use global 1.0
    var endSpeed: Float?         // nil = use global 1.0
    var languageCode: String?    // e.g., "ko-KR" or "en-US"
}

// For now, the idea is that this is a sentence or phrase, possibly with a speaker label
// In the future, we might want to add word-level timing, confidence, etc.
struct TranscriptSpan: Codable, Equatable {
    var startMs: Int
    var endMs: Int
    var text: String
    var speaker: String?
    var languageCode: String? // Used for TTS prompts, e.g., "en-US"
}

