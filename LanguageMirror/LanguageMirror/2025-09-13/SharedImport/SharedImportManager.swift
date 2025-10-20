//
//  SharedImportManager.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 10/19/25.
//

import Foundation

enum SharedImportError: Error {
    case appGroupNotConfigured
    case fileAccessDenied
    case invalidFileURL
    case copyFailed
}

/// Manages file transfers between the Share Extension and main app via App Groups
final class SharedImportManager {
    
    // MARK: - Configuration
    
    /// The App Group identifier - must match in both main app and extension
    /// IMPORTANT: Change this to match your actual App Group ID in Xcode
    static let appGroupIdentifier = "group.com.sixwandsstudios.LanguageMirror"
    
    private static let pendingImportsFileName = "pending_imports.json"
    private static let sharedFilesDirectoryName = "SharedFiles"
    
    // MARK: - Shared Container Access
    
    private static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    private static var sharedFilesDirectory: URL? {
        guard let container = sharedContainerURL else { return nil }
        let dir = container.appendingPathComponent(sharedFilesDirectoryName)
        
        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        return dir
    }
    
    private static var pendingImportsFileURL: URL? {
        sharedContainerURL?.appendingPathComponent(pendingImportsFileName)
    }
    
    // MARK: - Queue Management
    
    /// Add a file to the pending imports queue (called from Share Extension)
    static func enqueuePendingImport(sourceURL: URL, sourceName: String?) throws -> PendingImport {
        guard let sharedFilesDir = sharedFilesDirectory else {
            throw SharedImportError.appGroupNotConfigured
        }
        
        // Generate unique filename
        let fileExtension = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let uniqueFilename = "\(UUID().uuidString).\(fileExtension)"
        let destinationURL = sharedFilesDir.appendingPathComponent(uniqueFilename)
        
        // Copy file to shared container
        do {
            // If source requires security scoped access, handle it
            let needsAccess = sourceURL.startAccessingSecurityScopedResource()
            defer { if needsAccess { sourceURL.stopAccessingSecurityScopedResource() } }
            
            // Remove destination if it already exists (shouldn't happen with UUID, but be safe)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            
            // Verify source file exists
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                print("[SharedImport] Source file doesn't exist: \(sourceURL.path)")
                throw SharedImportError.invalidFileURL
            }
            
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            
            // Verify the copy succeeded
            guard FileManager.default.fileExists(atPath: destinationURL.path) else {
                print("[SharedImport] Copy succeeded but file not found at destination")
                throw SharedImportError.copyFailed
            }
            
        } catch let error as SharedImportError {
            throw error
        } catch {
            print("[SharedImport] Copy failed with error: \(error.localizedDescription)")
            print("[SharedImport] Source: \(sourceURL.path)")
            print("[SharedImport] Destination: \(destinationURL.path)")
            throw SharedImportError.copyFailed
        }
        
        // Create pending import record
        let pendingImport = PendingImport(
            fileURL: destinationURL,
            sourceName: sourceName
        )
        
        // Add to queue
        var queue = loadPendingImportsQueue()
        queue.imports.append(pendingImport)
        savePendingImportsQueue(queue)
        
        return pendingImport
    }
    
    /// Retrieve all pending imports (called from main app)
    static func retrievePendingImports() -> [PendingImport] {
        let queue = loadPendingImportsQueue()
        return queue.imports
    }
    
    /// Clear a specific pending import (called from main app after processing)
    static func clearPendingImport(id: String) {
        var queue = loadPendingImportsQueue()
        queue.imports.removeAll { $0.id == id }
        savePendingImportsQueue(queue)
    }
    
    /// Clear all pending imports
    static func clearAllPendingImports() {
        savePendingImportsQueue(PendingImportsQueue(imports: []))
    }
    
    /// Delete the file associated with a pending import
    static func deleteSharedFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - Private Helpers
    
    private static func loadPendingImportsQueue() -> PendingImportsQueue {
        guard let fileURL = pendingImportsFileURL else {
            return PendingImportsQueue(imports: [])
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let queue = try? JSONDecoder().decode(PendingImportsQueue.self, from: data) else {
            return PendingImportsQueue(imports: [])
        }
        
        return queue
    }
    
    private static func savePendingImportsQueue(_ queue: PendingImportsQueue) {
        guard let fileURL = pendingImportsFileURL else { return }
        
        do {
            let data = try JSONEncoder().encode(queue)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save pending imports queue: \(error)")
        }
    }
}

