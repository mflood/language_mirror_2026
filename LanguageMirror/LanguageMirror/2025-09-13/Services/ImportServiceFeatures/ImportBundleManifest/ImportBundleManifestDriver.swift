//
//  ImportBundleManifestDriver.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

@preconcurrency import AVFoundation
import Foundation

public enum BundleManifestError: Error {
    case invalidManifestURL(String)
    case manifestDownloadFailed(underlying: Error)
    case manifestNotJSON
    case manifestParseFailed(underlying: Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidManifestURL(let reason):
            return "Invalid manifest URL: \(reason)"
        case .manifestDownloadFailed(let error):
            return "Failed to download manifest: \(error.localizedDescription)"
        case .manifestNotJSON:
            return "The downloaded file is not a valid JSON manifest. Please check the URL."
        case .manifestParseFailed(let error):
            return "Failed to parse manifest JSON: \(error.localizedDescription)"
        }
    }
}

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
            throw BundleManifestError.invalidManifestURL("URL must use http:// or https://")
        }
        
        // Validate that this looks like a JSON manifest URL (defensive check)
        let pathExtension = manifestURL.pathExtension.lowercased()
        if !pathExtension.isEmpty && pathExtension != "json" {
            print("⚠️ [BundleManifestDriver] URL path extension is '\(pathExtension)', expected 'json' or none")
            print("⚠️ [BundleManifestDriver] This might be a manifest URL, continuing anyway...")
        }
        
        print("📥 [BundleManifestDriver] Starting download from: \(manifestURL.absoluteString)")
        let downloadStartTime = Date()
        
        // Download manifest (URLSession handles this asynchronously)
        // IMPORTANT: We use NetworkSession.shared.download() directly, NOT urlDownloader.downloadAudio()
        // This ensures JSON manifests are never processed as audio files
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
            
            // Check if this error is from audio downloader (should never happen for manifests)
            if error is RemoteImportError {
                print("⚠️ [BundleManifestDriver] WARNING: Got RemoteImportError - manifest was incorrectly processed as audio!")
                print("⚠️ [BundleManifestDriver] This indicates a bug - manifests should use NetworkSession, not urlDownloader")
            }
            
            if let urlError = error as? URLError {
                print("❌ [BundleManifestDriver] URLError code: \(urlError.code.rawValue)")
                print("❌ [BundleManifestDriver] URLError description: \(urlError.localizedDescription)")
            }
            
            // Wrap in our specific error type to distinguish from audio download errors
            throw BundleManifestError.manifestDownloadFailed(underlying: error)
        }
        
        // Check response status and content type
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 [BundleManifestDriver] HTTP status: \(httpResponse.statusCode)")
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
            print("📥 [BundleManifestDriver] Content-Type: \(contentType)")
            print("📥 [BundleManifestDriver] Content-Length: \(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "unknown")")
            
            if !(200..<300).contains(httpResponse.statusCode) {
                print("❌ [BundleManifestDriver] Bad HTTP status: \(httpResponse.statusCode)")
                throw BundleManifestError.manifestDownloadFailed(underlying: URLError(.badServerResponse))
            }
            
            // Validate that response is JSON (defensive check)
            let contentTypeLower = contentType.lowercased()
            if !contentTypeLower.contains("json") && !contentTypeLower.contains("application/json") && !contentTypeLower.contains("text/json") {
                print("⚠️ [BundleManifestDriver] Content-Type '\(contentType)' doesn't indicate JSON")
                print("⚠️ [BundleManifestDriver] Proceeding anyway - will validate during parsing")
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
        
        // Validate that data looks like JSON (quick sanity check)
        if manifestData.isEmpty {
            print("❌ [BundleManifestDriver] Downloaded manifest data is empty")
            throw BundleManifestError.manifestNotJSON
        }
        
        // Quick check: JSON should start with '{' or '[' or whitespace
        let whitespaceChars: [UInt8] = [9, 10, 13, 32] // tab, LF, CR, space
        if let firstNonWhitespace = manifestData.first(where: { !whitespaceChars.contains($0) }),
           firstNonWhitespace != UInt8(ascii: "{") && firstNonWhitespace != UInt8(ascii: "[") {
            print("❌ [BundleManifestDriver] Downloaded data doesn't appear to be JSON (starts with '\(Character(UnicodeScalar(firstNonWhitespace)))')")
            throw BundleManifestError.manifestNotJSON
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
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                    print("❌ [BundleManifestDriver] Type mismatch for '\(type)' at path: \(path)")
                    
                    // Provide specific guidance for common errors
                    let typeDescription = String(describing: type)
                    if path.contains("clips") && typeDescription.contains("Dictionary") {
                        print("❌ [BundleManifestDriver] ERROR: The 'clips' field must be either:")
                        print("   - null (if no practice clips)")
                        print("   - A PracticeSet object with: { id, trackId, displayOrder, title, clips: [Clip], isFavorite }")
                        print("   - Found array instead. If you have an array of clips, wrap it in a PracticeSet object.")
                        print("   - Example correct format:")
                        print("     \"clips\": {")
                        print("       \"id\": \"uuid-string\",")
                        print("       \"trackId\": \"uuid-string\",")
                        print("       \"displayOrder\": 0,")
                        print("       \"title\": \"Practice Set\",")
                        print("       \"clips\": [ ... array of Clip objects ... ],")
                        print("       \"isFavorite\": false")
                        print("     }")
                    }
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
            throw BundleManifestError.manifestParseFailed(underlying: error)
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
                print("🎵 [BundleManifestDriver] Downloading audio file: \(audioURL.absoluteString)")
                let (tempAudio, suggestedFilename): (URL, String)
                do {
                    (tempAudio, suggestedFilename) = try await urlDownloader.downloadAudio(from: audioURL)
                    print("✅ [BundleManifestDriver] Audio file downloaded successfully")
                } catch {
                    print("❌ [BundleManifestDriver] Failed to download audio file: \(error)")
                    print("❌ [BundleManifestDriver] Audio URL was: \(audioURL.absoluteString)")
                    throw error
                }
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
                
                /* TODO: fix this
                if let practiceSets = bundleTrack.practiceSets {
                 
                 
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
                 */
                
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
