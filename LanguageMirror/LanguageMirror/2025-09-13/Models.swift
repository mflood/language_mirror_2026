//
//  Models.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import Foundation

enum AudioSourceType: String, Codable, Hashable {
    case textbook, voiceMemo, localRecording, videoExtract, youtube, tts
}

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
    var practiceSets: [PracticeSet]
    var transcripts: [TranscriptSpan]
    var tags: [String]
    var sourceType: AudioSourceType
    var createdAt: Date?      // Timestamp of when the track was imported
}

struct PracticeSet: Codable, Equatable {
    var id: String           // UUID string so we can reference it from practice sessions
    var trackId: String  // If we tag clips to play in a playlist, we can reference the track here
    var displayOrder: Int
    var title: String?
    var clips: [Clip]
    var isFavorite: Bool = false
    
    static func fullTrackFactory(trackId: String, displayOrder: Int, trackDurationMs: Int? = nil) -> PracticeSet {
        // Use actual track duration if provided, otherwise use a safe default
        let endMs = trackDurationMs ?? 9999999
        return PracticeSet(
            id: UUID().uuidString,
            trackId: trackId,
            displayOrder: displayOrder,
            title: "Practice Set",
            clips: [
                Clip(id: UUID().uuidString, startMs: 0, endMs: endMs, kind: .drill, title: "Full Track", repeats: nil, startSpeed: nil, endSpeed: nil)
            ]
        )
    }
}

enum ClipKind: String, Codable, CaseIterable { case drill, skip, noise }

extension ClipKind {
    var label: String {
        switch self {
        case .drill:  return "Drill"
        case .skip: return "Skip"
        case .noise: return "Noise"
        }
    }
}

struct Clip: Codable, Identifiable, Equatable {
    let id: String
    var startMs: Int
    var endMs: Int
    var kind: ClipKind
    var title: String?
    var repeats: Int?            // nil = use global N
    var startSpeed: Float?       // nil = use global 1.0
    var endSpeed: Float?         // nil = use global 1.0
    var languageCode: String?    // e.g., "ko-KR" or "en-US"
    // transcript
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


struct StudySession: Codable, Hashable {
    let id: UUID
    let userId: UUID
    let trackId: UUID
    let arrangementId: UUID
    let started: Date
    let ended: Date
    let slicesCompleted: Int
    let totalLoops: Int
}



struct TrackProgress: Codable, Hashable {
    var trackId: UUID
    var arrangementId: UUID?      // last arrangement studied
    var currentSliceIndex: Int    // 0-based slice pointer
    var loopsCompleted: Int       // loops finished on current slice
    var customLoopCount: Int?     // user override
    var lastUpdated: Date
    var currentSpeed: Float?
    
    var totalRepititions: Int?
    var currentRepetion: Int?
    
    
}

// MARK: - Practice Session Models

enum SpeedMode: String, Codable, CaseIterable {
    case constantMin      // Always play at min speed
    case constantMax      // Always play at max speed
    case linear           // Gradually increase from min to max over all loops
    case minThenLinear    // Play first N loops at min, then linear progression
    case linearThenMax    // Linear progression for N loops, then max for rest
    
    var label: String {
        switch self {
        case .constantMin: return "Min"
        case .constantMax: return "Max"
        case .linear: return "Linear"
        case .minThenLinear: return "Min→Linear"
        case .linearThenMax: return "Linear→Max"
        }
    }
    
    var usesN: Bool {
        switch self {
        case .minThenLinear, .linearThenMax: return true
        case .constantMin, .constantMax, .linear: return false
        }
    }
}

struct ClipPlayCount: Codable, Equatable {
    let clipId: String
    var playCount: Int
}

struct PracticeSession: Codable, Equatable {
    let id: String
    let packId: String
    let trackId: String
    let practiceSetId: String
    var currentClipIndex: Int
    var currentLoopCount: Int
    var currentSpeed: Float
    var clipPlayCounts: [String: Int]  // clipId -> count
    var foreverMode: Bool
    let createdAt: Date
    var lastUpdatedAt: Date
    
    init(practiceSetId: String, packId: String, trackId: String) {
        self.id = UUID().uuidString
        self.practiceSetId = practiceSetId
        self.packId = packId
        self.trackId = trackId
        self.currentClipIndex = 0
        self.currentLoopCount = 0
        self.currentSpeed = 1.0
        self.clipPlayCounts = [:]
        self.foreverMode = false
        let now = Date()
        self.createdAt = now
        self.lastUpdatedAt = now
    }
}
