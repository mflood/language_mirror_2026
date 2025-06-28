//
//  TrackProgress.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//

import Foundation

// MARK: - Per-Track Progress  (one per user ↔ track)
struct TrackProgress: Codable, Hashable {
    var trackId: UUID
    var arrangementId: UUID?      // last arrangement studied
    var currentSliceIndex: Int    // 0-based slice pointer
    var loopsCompleted: Int       // loops finished on current slice
    var customLoopCount: Int?     // user override
    var lastUpdated: Date
}
