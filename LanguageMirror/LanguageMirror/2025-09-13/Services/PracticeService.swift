//
//  PracticeService.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 10/20/25.
//

// path: Services/PracticeService.swift
import Foundation

protocol PracticeService: AnyObject {
    /// Create a new practice session for the given practice set
    func createSession(practiceSet: PracticeSet, packId: String, trackId: String) throws -> PracticeSession
    
    /// Load an existing session for a given pack and track
    func loadSession(packId: String, trackId: String) throws -> PracticeSession?
    
    /// Save the current state of a practice session
    func saveSession(_ session: PracticeSession) throws
    
    /// Delete a practice session for a given pack and track
    func deleteSession(packId: String, trackId: String) throws
    
    /// Delete all sessions for a given pack
    func deleteSessionsForPack(packId: String) throws
    
    /// Update the progress of a practice session
    func updateProgress(session: inout PracticeSession, clipIndex: Int, loopCount: Int, speed: Float) throws
    
    /// Increment the play count for a specific clip
    func incrementClipPlayCount(session: inout PracticeSession, clipId: String) throws
    
    /// List recent practice sessions sorted by most recent first
    func listRecentSessions(limit: Int) -> [(packId: String, trackId: String, lastUpdated: Date)]
    
    /// Calculate the current speed based on progression mode and settings
    func calculateSpeed(useProgressionMode: Bool, currentLoop: Int, progressionMinRepeats: Int, progressionLinearRepeats: Int, progressionMaxRepeats: Int, minSpeed: Float, maxSpeed: Float) -> Float
}

enum PracticeServiceError: Error, LocalizedError {
    case sessionNotFound
    case invalidPath
    case saveFailed(String)
    case loadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .sessionNotFound: return "Practice session not found"
        case .invalidPath: return "Invalid file path"
        case .saveFailed(let msg): return "Failed to save session: \(msg)"
        case .loadFailed(let msg): return "Failed to load session: \(msg)"
        }
    }
}

