//
//  PracticeServiceJSON.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 10/20/25.
//

// path: Services/PracticeServiceJSON.swift
import Foundation

final class PracticeServiceJSON: PracticeService {
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Serial queue for file operations to avoid blocking main thread
    private let ioQueue = DispatchQueue(label: "com.languagemirror.practiceservice.io", qos: .userInitiated)
    
    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        // Ensure practice sessions directory exists
        try? createSessionsDirectoryIfNeeded()
    }
    
    // MARK: - Directory Management
    
    private func sessionsDirectoryURL() throws -> URL {
        let docs = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return docs.appendingPathComponent("practice_sessions", isDirectory: true)
    }
    
    private func createSessionsDirectoryIfNeeded() throws {
        let url = try sessionsDirectoryURL()
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    private func sessionFileURL(packId: String, trackId: String) throws -> URL {
        let dir = try sessionsDirectoryURL()
        let filename = "session_\(packId)_\(trackId).json"
        return dir.appendingPathComponent(filename)
    }
    
    // MARK: - PracticeService Implementation
    
    func createSession(practiceSet: PracticeSet, packId: String, trackId: String) throws -> PracticeSession {
        let session = PracticeSession(practiceSetId: practiceSet.id, packId: packId, trackId: trackId)
        try saveSession(session)
        return session
    }
    
    func loadSession(packId: String, trackId: String) throws -> PracticeSession? {
        let url = try sessionFileURL(packId: packId, trackId: trackId)
        
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let session = try decoder.decode(PracticeSession.self, from: data)
            return session
        } catch {
            throw PracticeServiceError.loadFailed(error.localizedDescription)
        }
    }
    
    func saveSession(_ session: PracticeSession) throws {
        let url = try sessionFileURL(packId: session.packId, trackId: session.trackId)
        
        var mutableSession = session
        mutableSession.lastUpdatedAt = Date()
        
        // Encode on current thread (fast)
        let data = try encoder.encode(mutableSession)
        
        // Write to disk on background queue (slow I/O)
        ioQueue.async {
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                print("Failed to save practice session: \(error)")
            }
        }
    }
    
    func deleteSession(packId: String, trackId: String) throws {
        let url = try sessionFileURL(packId: packId, trackId: trackId)
        
        guard fileManager.fileExists(atPath: url.path) else {
            return // Nothing to delete
        }
        
        // Delete on background queue
        ioQueue.async {
            do {
                try self.fileManager.removeItem(at: url)
            } catch {
                print("Failed to delete practice session: \(error)")
            }
        }
    }
    
    func deleteSessionsForPack(packId: String) throws {
        let dir = try sessionsDirectoryURL()
        let prefix = "session_\(packId)_"
        
        // Delete on background queue
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let contents = try self.fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                
                for fileURL in contents {
                    let filename = fileURL.lastPathComponent
                    if filename.hasPrefix(prefix) && filename.hasSuffix(".json") {
                        try self.fileManager.removeItem(at: fileURL)
                    }
                }
            } catch {
                print("Failed to delete pack sessions: \(error)")
            }
        }
    }
    
    func updateProgress(session: inout PracticeSession, clipIndex: Int, loopCount: Int, speed: Float) throws {
        session.currentClipIndex = clipIndex
        session.currentLoopCount = loopCount
        session.currentSpeed = speed
        session.lastUpdatedAt = Date()
        try saveSession(session)
    }
    
    func incrementClipPlayCount(session: inout PracticeSession, clipId: String) throws {
        let currentCount = session.clipPlayCounts[clipId] ?? 0
        session.clipPlayCounts[clipId] = currentCount + 1
        session.lastUpdatedAt = Date()
        try saveSession(session)
    }
    
    func listRecentSessions(limit: Int) -> [(packId: String, trackId: String, lastUpdated: Date)] {
        guard let dir = try? sessionsDirectoryURL(),
              let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return []
        }
        
        var sessions: [(packId: String, trackId: String, lastUpdated: Date)] = []
        
        for fileURL in contents {
            guard fileURL.pathExtension == "json",
                  let data = try? Data(contentsOf: fileURL),
                  let session = try? decoder.decode(PracticeSession.self, from: data) else {
                continue
            }
            
            sessions.append((packId: session.packId, trackId: session.trackId, lastUpdated: session.lastUpdatedAt))
        }
        
        // Sort by most recent first
        sessions.sort { $0.lastUpdated > $1.lastUpdated }
        
        return Array(sessions.prefix(limit))
    }
    
    func calculateSpeed(mode: SpeedMode, currentLoop: Int, totalLoops: Int, minSpeed: Float, maxSpeed: Float, modeN: Int) -> Float {
        // Ensure we have at least 1 loop to avoid division by zero
        guard totalLoops > 0 else { return minSpeed }
        
        switch mode {
        case .constantMin:
            return minSpeed
            
        case .constantMax:
            return maxSpeed
            
        case .linear:
            // Linear progression from min to max over all loops
            let progress = Float(currentLoop) / Float(totalLoops)
            return minSpeed + (maxSpeed - minSpeed) * progress
            
        case .minThenLinear:
            // First N loops at min speed, then linear progression
            if currentLoop < modeN {
                return minSpeed
            } else {
                let remainingLoops = totalLoops - modeN
                guard remainingLoops > 0 else { return maxSpeed }
                let loopsIntoLinear = currentLoop - modeN
                let progress = Float(loopsIntoLinear) / Float(remainingLoops)
                return minSpeed + (maxSpeed - minSpeed) * progress
            }
            
        case .linearThenMax:
            // Linear progression for N loops, then max for the rest
            if currentLoop < modeN {
                let progress = Float(currentLoop) / Float(modeN)
                return minSpeed + (maxSpeed - minSpeed) * progress
            } else {
                return maxSpeed
            }
        }
    }
}

