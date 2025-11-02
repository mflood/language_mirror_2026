//
//  ImportBundleManifestDriver.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

@preconcurrency import AVFoundation
import Foundation

final class ImportBundleManifestDriver {
    private let urlDownloader: UrlDownloaderProtocol
    private let library: LibraryService
    private let fm = FileManager.default
    
    init(urlDownloader: UrlDownloaderProtocol, library: LibraryService) {
        self.urlDownloader = urlDownloader
        self.library = library
    }
    
    func run(manifestURL: URL, progress: (@Sendable (Float) -> Void)? = nil, progressMessage: ((@Sendable (String) -> Void)? )) async throws -> [Track] {
        print("🚀 [BundleManifestDriver] Starting import for URL: \(manifestURL.absoluteString)")
        print("🚀 [BundleManifestDriver] URL scheme: \(manifestURL.scheme ?? "nil")")
        print("🚀 [BundleManifestDriver] URL host: \(manifestURL.host ?? "nil")")
        print("🚀 [BundleManifestDriver] Current thread: \(Thread.isMainThread ? "main" : "background")")
        
        try Task.checkCancellation()
        
        guard let lib = library as? LibraryServiceJSON else {
            print("❌ [BundleManifestDriver] LibraryService is not LibraryServiceJSON")
            throw LibraryError.writeFailed
        }
        
        // 1) Download and parse JSON manifest
        // Dispatch progress updates asynchronously to avoid blocking
        progress?(0.1)
        progressMessage?("Downloading manifest...")
        
        // Validate manifest URL scheme
        guard let scheme = manifestURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            print("❌ [BundleManifestDriver] Invalid URL scheme: \(manifestURL.scheme ?? "nil")")
            throw URLError(.unsupportedURL)
        }
        
        print("📥 [BundleManifestDriver] Starting download from: \(manifestURL.absoluteString)")
        let downloadStartTime = Date()
        
        // Download manifest (URLSession handles this asynchronously)
        let (tempManifest, response): (URL, URLResponse)
        do {
            (tempManifest, response) = try await NetworkSession.shared.download(from: manifestURL)
            let downloadDuration = Date().timeIntervalSince(downloadStartTime)
            print("✅ [BundleManifestDriver] Download completed in \(String(format: "%.2f", downloadDuration))s")
            print("📥 [BundleManifestDriver] Downloaded to temp file: \(tempManifest.path)")
        } catch {
            let downloadDuration = Date().timeIntervalSince(downloadStartTime)
            print("❌ [BundleManifestDriver] Download failed after \(String(format: "%.2f", downloadDuration))s")
            print("❌ [BundleManifestDriver] Error: \(error)")
            print("❌ [BundleManifestDriver] Error type: \(type(of: error))")
            if let urlError = error as? URLError {
                print("❌ [BundleManifestDriver] URLError code: \(urlError.code.rawValue)")
                print("❌ [BundleManifestDriver] URLError description: \(urlError.localizedDescription)")
            }
            throw error
        }
        
        // Check response status
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 [BundleManifestDriver] HTTP status: \(httpResponse.statusCode)")
            print("📥 [BundleManifestDriver] Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
            print("📥 [BundleManifestDriver] Content-Length: \(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "unknown")")
            
            if !(200..<300).contains(httpResponse.statusCode) {
                print("❌ [BundleManifestDriver] Bad HTTP status: \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
        } else {
            print("⚠️ [BundleManifestDriver] Response is not HTTPURLResponse: \(type(of: response))")
        }
        
        try Task.checkCancellation()
        progress?(0.2)
        progressMessage?("Reading manifest...")
        
        print("📖 [BundleManifestDriver] Reading manifest file from: \(tempManifest.path)")
        let readStartTime = Date()
        
        // Read file data asynchronously to avoid blocking
        let manifestData: Data
        do {
            manifestData = try await Task.detached(priority: .userInitiated) {
                let data = try Data(contentsOf: tempManifest)
                print("📖 [BundleManifestDriver] Read \(data.count) bytes from temp file")
                return data
            }.value
            let readDuration = Date().timeIntervalSince(readStartTime)
            print("✅ [BundleManifestDriver] File read completed in \(String(format: "%.2f", readDuration))s")
            print("📖 [BundleManifestDriver] Manifest data size: \(manifestData.count) bytes")
        } catch {
            print("❌ [BundleManifestDriver] Failed to read manifest file: \(error)")
            throw error
        }
        
        defer {
            try? FileManager.default.removeItem(at: tempManifest)
        }
        
        // Decode JSON (lightweight operation)
        print("🔍 [BundleManifestDriver] Parsing JSON manifest...")
        let decodeStartTime = Date()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bundleManifest: BundleManifest
        do {
            bundleManifest = try decoder.decode(BundleManifest.self, from: manifestData)
            let decodeDuration = Date().timeIntervalSince(decodeStartTime)
            print("✅ [BundleManifestDriver] JSON parsing completed in \(String(format: "%.3f", decodeDuration))s")
            print("📦 [BundleManifestDriver] Bundle title: \(bundleManifest.title)")
            print("📦 [BundleManifestDriver] Number of packs: \(bundleManifest.packs.count)")
            let totalTracks = bundleManifest.packs.reduce(0) { $0 + $1.tracks.count }
            print("📦 [BundleManifestDriver] Total tracks: \(totalTracks)")
        } catch {
            print("❌ [BundleManifestDriver] JSON parsing failed: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ [BundleManifestDriver] Missing key '\(key.stringValue)' at path: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("❌ [BundleManifestDriver] Type mismatch for '\(type)' at path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("❌ [BundleManifestDriver] Missing value for '\(type)' at path: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("❌ [BundleManifestDriver] Data corrupted at path: \(context.codingPath)")
                    if let underlyingError = context.underlyingError {
                        print("❌ [BundleManifestDriver] Underlying error: \(underlyingError)")
                    }
                @unknown default:
                    print("❌ [BundleManifestDriver] Unknown decoding error")
                }
            }
            throw error
        }
        
        try Task.checkCancellation()
        progress?(0.3)
        
        // Use DNS namespace for deterministic UUID generation
        let bundleNamespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")! // DNS namespace
        let bundleUUID = uuid5(namespace: bundleNamespace, name: norm(bundleManifest.title))
        
        var allTracks: [Track] = []
        let totalPacks = bundleManifest.packs.count
        let totalTracks = bundleManifest.packs.reduce(0) { $0 + $1.tracks.count }
        var processedTracks = 0
        
        // 2) Process each pack
        for (packIndex, bundlePack) in bundleManifest.packs.enumerated() {
            try Task.checkCancellation()
            
            // Generate deterministic pack UUID
            let packIdOrTitle = bundlePack.id ?? bundlePack.title
            let packUUID = uuid5(namespace: bundleUUID, name: norm(packIdOrTitle))
            let packId = packUUID.uuidString
            
            // Create or update pack
            let pack = Pack(
                id: packId,
                title: bundlePack.title,
                languageHint: nil, // Can be set from first track if needed
                tracks: []
            )
            try library.addPack(pack)
            
            // 3) Process each track in the pack
            for (trackIndex, bundleTrack) in bundlePack.tracks.enumerated() {
                try Task.checkCancellation()
                
                // Calculate progress: 30% base + 70% for packs/tracks
                let packProgress = Float(packIndex) / Float(totalPacks)
                let trackProgress = Float(trackIndex) / Float(bundlePack.tracks.count)
                let overallProgress = 0.3 + 0.7 * (packProgress + trackProgress / Float(totalPacks))
                progress?(overallProgress)
                
                // Ensure we have an audio URL
                guard let audioURLString = bundleTrack.url,
                      let audioURL = URL(string: audioURLString) else {
                    print("Skipping track '\(bundleTrack.title)' - missing audio URL")
                    continue
                }
                
                // Validate audio URL scheme
                guard let audioScheme = audioURL.scheme?.lowercased(),
                      audioScheme == "http" || audioScheme == "https" else {
                    print("Skipping track '\(bundleTrack.title)' - invalid URL scheme: \(audioURL.scheme ?? "none")")
                    continue
                }
                
                // Update progress message with file count (only for files we're actually downloading)
                let currentFileNumber = processedTracks + 1
                progressMessage?("Downloading file \(currentFileNumber)/\(totalTracks)...")
                
                // Generate deterministic track UUID
                let trackIdOrTitle = bundleTrack.id ?? bundleTrack.title
                let trackUUID = uuid5(namespace: packUUID, name: norm(trackIdOrTitle + bundleTrack.url!))
                let trackId = trackUUID.uuidString
                
                // Download audio file
                let (tempAudio, suggestedFilename) = try await urlDownloader.downloadAudio(from: audioURL)
                defer {
                    try? FileManager.default.removeItem(at: tempAudio)
                }
                
                try Task.checkCancellation()
                
                // Determine final filename
                let finalFilename: String
                if let specifiedFilename = bundleTrack.filename, !specifiedFilename.isEmpty {
                    finalFilename = specifiedFilename
                } else {
                    finalFilename = suggestedFilename
                }
                
                let fileExtension = (finalFilename as NSString).pathExtension.isEmpty 
                    ? (audioURL.pathExtension.isEmpty ? "mp3" : audioURL.pathExtension)
                    : (finalFilename as NSString).pathExtension
                
                let filename = "audio.\(fileExtension)"
                
                // Create track folder and save audio
                let folder = lib.trackFolder(forPackId: packId, forTrackId: trackId)
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                let dest = folder.appendingPathComponent(filename)
                if fm.fileExists(atPath: dest.path) { 
                    try fm.removeItem(at: dest) 
                }
                try fm.copyItem(at: tempAudio, to: dest)
                
                try Task.checkCancellation()
                
                // Get duration
                var durationMs = bundleTrack.durationMs
                if durationMs == nil {
                    let duration = try await AVURLAsset(url: dest).load(.duration).seconds
                    durationMs = Int((duration.isFinite ? duration : 0) * 1000.0)
                }
                
                // Import practice sets
                var trackPracticeSets: [PracticeSet] = []
                if let clips = bundleTrack.clips {
                    // Create practice set with correct IDs
                    let practiceSetId = clips.id.isEmpty 
                        ? uuid5(namespace: trackUUID, name: norm(clips.title ?? "Practice Set")).uuidString
                        : clips.id
                    
                    let practiceSet = PracticeSet(
                        id: practiceSetId,
                        trackId: trackId,
                        displayOrder: clips.displayOrder,
                        title: clips.title,
                        clips: clips.clips,
                        isFavorite: clips.isFavorite
                    )
                    trackPracticeSets.append(practiceSet)
                }
                
                // Import transcripts
                let transcripts = bundleTrack.transcripts ?? []
                
                // Generate tags
                let tags = autoTagsForTrack(sourceType: .textbook, languageCode: nil, fileExtension: fileExtension)
                
                // Create track
                let track = Track(
                    id: trackId,
                    packId: packId,
                    title: bundleTrack.title,
                    filename: filename,
                    localUrl: dest,
                    durationMs: durationMs,
                    languageCode: nil,
                    practiceSets: trackPracticeSets,
                    transcripts: transcripts,
                    tags: tags,
                    sourceType: .textbook,
                    createdAt: Date()
                )
                
                try library.addTrack(track, to: packId)
                allTracks.append(track)
                processedTracks += 1
                
                progress?(0.3 + 0.7 * Float(processedTracks) / Float(totalTracks))
            }
        }
        
        progress?(1.0)
        return allTracks
    }
}
