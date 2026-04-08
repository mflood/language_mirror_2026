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

    /// Import a bundle that lives inside the app's main bundle Resources folder.
    /// The bundle is described by a `<sanitizedId>.bundle.json` manifest using
    /// the same schema as a remote (QR / URL) bundle, but audio files are
    /// looked up by filename in the (flat) main bundle resources.
    ///
    /// The Python helper `sample_bundle_pipeline/4_embed_in_app.py` produces
    /// the prefixed manifest + audio files this method expects.
    func runFromAppBundle(bundleId: String) async throws -> [Track] {
        let sanitized = sanitizeForFilename(bundleId)
        let manifestResource = "\(sanitized).bundle"
        guard let manifestURL = Bundle.main.url(forResource: manifestResource, withExtension: "json") else {
            throw BundleManifestError.invalidManifestURL(
                "Missing embedded manifest '\(manifestResource).json' in app bundle. " +
                "Did you run sample_bundle_pipeline/4_embed_in_app.py?"
            )
        }
        let data = try Data(contentsOf: manifestURL)
        let manifest = try parseManifest(data: data)
        let resolver = AppBundleAudioSourceResolver()
        return try await processBundleManifest(manifest, audioResolver: resolver, progress: nil, progressMessage: nil)
    }

    /// Match the sanitization done by sample_bundle_pipeline/4_embed_in_app.py:
    /// keep alphanumerics, dash and underscore; replace everything else with `_`.
    private func sanitizeForFilename(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            if ch.isLetter || ch.isNumber || ch == "-" || ch == "_" {
                out.append(ch)
            } else {
                out.append("_")
            }
        }
        return out
    }

    func run(manifestURL: URL, progress: (@Sendable (Float) -> Void)? = nil, progressMessage: ((@Sendable (String) -> Void)? )) async throws -> [Track] {
        print("🚀 [BundleManifestDriver] Starting import for URL: \(manifestURL.absoluteString)")
        print("🚀 [BundleManifestDriver] URL scheme: \(manifestURL.scheme ?? "nil")")
        print("🚀 [BundleManifestDriver] URL host: \(manifestURL.host ?? "nil")")
        print("🚀 [BundleManifestDriver] Current thread: \(Thread.isMainThread ? "main" : "background")")
        
        try Task.checkCancellation()
        
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
        
        let downloadStartTime = Date()
        
        // Download manifest with detailed progress logging
        // IMPORTANT: We use NetworkSession.shared.downloadWithProgress() directly, NOT urlDownloader.downloadAudio()
        // This ensures JSON manifests are never processed as audio files
        let (tempManifest, response): (URL, URLResponse)
        do {
            (tempManifest, response) = try await NetworkSession.shared.downloadWithProgress(from: manifestURL, logPrefix: "📥 [BundleManifestDriver]")
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
        
        let bundleManifest = try parseManifest(data: manifestData)

        try Task.checkCancellation()
        progress?(0.3)

        let resolver = RemoteAudioSourceResolver(urlDownloader: urlDownloader)
        return try await processBundleManifest(bundleManifest, audioResolver: resolver, progress: progress, progressMessage: progressMessage)
    }

    // MARK: - Shared parsing & processing

    /// Parse a bundle manifest from raw JSON bytes. Used by both remote and
    /// app-bundle import paths.
    private func parseManifest(data manifestData: Data) throws -> BundleManifest {
        print("🔍 [BundleManifestDriver] Parsing JSON manifest...")
        let decodeStartTime = Date()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let bundleManifest = try decoder.decode(BundleManifest.self, from: manifestData)
            let decodeDuration = Date().timeIntervalSince(decodeStartTime)
            print("✅ [BundleManifestDriver] JSON parsing completed in \(String(format: "%.3f", decodeDuration))s")
            print("📦 [BundleManifestDriver] Bundle title: \(bundleManifest.title)")
            print("📦 [BundleManifestDriver] Number of packs: \(bundleManifest.packs.count)")
            let totalTracks = bundleManifest.packs.reduce(0) { $0 + $1.tracks.count }
            print("📦 [BundleManifestDriver] Total tracks: \(totalTracks)")
            return bundleManifest
        } catch {
            print("❌ [BundleManifestDriver] JSON parsing failed: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ [BundleManifestDriver] Missing key '\(key.stringValue)' at path: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                    print("❌ [BundleManifestDriver] Type mismatch for '\(type)' at path: \(path)")
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
    }

    /// Per-track import loop, source-agnostic. Audio bytes are obtained via the
    /// supplied `audioResolver`, which knows whether to download or to read
    /// from app resources.
    private func processBundleManifest(
        _ bundleManifest: BundleManifest,
        audioResolver: AudioSourceResolver,
        progress: (@Sendable (Float) -> Void)?,
        progressMessage: (@Sendable (String) -> Void)?
    ) async throws -> [Track] {
        guard let lib = library as? LibraryServiceJSON else {
            throw LibraryError.writeFailed
        }
        
        // Use DNS namespace for deterministic UUID generation
        let bundleNamespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")! // DNS namespace
        // Prefer stable manifest id for deterministic imports (backward compatible with older manifests)
        let bundleStableId = bundleManifest.id ?? bundleManifest.title
        let bundleUUID = uuid5(namespace: bundleNamespace, name: norm(bundleStableId))
        
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
                
                // Update progress message with file count
                let currentFileNumber = processedTracks + 1
                progressMessage?("Loading file \(currentFileNumber)/\(totalTracks)...")

                // Resolve the audio source (download from URL or read from app bundle)
                let resolved: ResolvedAudio
                do {
                    resolved = try await audioResolver.resolve(track: bundleTrack)
                } catch {
                    print("Skipping track '\(bundleTrack.title)' - resolve failed: \(error)")
                    continue
                }
                let cleanupSourceURL = resolved.url
                let isTemporary = resolved.isTemporary
                defer {
                    if isTemporary { try? FileManager.default.removeItem(at: cleanupSourceURL) }
                }

                try Task.checkCancellation()

                // Generate deterministic track UUID using whatever stable identity we have
                let trackIdOrTitle = bundleTrack.id ?? bundleTrack.title
                let trackIdentity = bundleTrack.url ?? bundleTrack.filename ?? resolved.suggestedFilename
                let trackUUID = uuid5(namespace: packUUID, name: norm(trackIdOrTitle + trackIdentity))
                let trackId = trackUUID.uuidString

                // Determine final filename + extension
                let finalFilename: String
                if let specifiedFilename = bundleTrack.filename, !specifiedFilename.isEmpty {
                    finalFilename = specifiedFilename
                } else {
                    finalFilename = resolved.suggestedFilename
                }

                let fileExtension = (finalFilename as NSString).pathExtension.isEmpty
                    ? (resolved.url.pathExtension.isEmpty ? "mp3" : resolved.url.pathExtension)
                    : (finalFilename as NSString).pathExtension

                let filename = "audio.\(fileExtension)"

                // Create track folder and save audio
                let folder = lib.trackFolder(forPackId: packId, forTrackId: trackId)
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                let dest = folder.appendingPathComponent(filename)
                if fm.fileExists(atPath: dest.path) {
                    try fm.removeItem(at: dest)
                }
                try fm.copyItem(at: resolved.url, to: dest)
                
                try Task.checkCancellation()
                
                // Get duration
                var durationMs = bundleTrack.durationMs
                if durationMs == nil {
                    let duration = try await AVURLAsset(url: dest).load(.duration).seconds
                    durationMs = Int((duration.isFinite ? duration : 0) * 1000.0)
                }
                
                // Import practice sets
                var trackPracticeSets: [PracticeSet] = []
                
                if let practiceSets = bundleTrack.practiceSets {
                    print("📦 [BundleManifestDriver] Importing \(practiceSets.count) practice set(s) for track '\(bundleTrack.title)'")
                    
                    for practiceSet in practiceSets {
                        // Create a new PracticeSet with the correct trackId (replace placeholder from JSON)
                        // Preserve all other fields (id, displayOrder, title, clips, isFavorite) from JSON
                        let updatedPracticeSet = PracticeSet(
                            id: practiceSet.id,
                            trackId: trackId, // Use actual generated trackId, not placeholder from JSON
                            displayOrder: practiceSet.displayOrder,
                            title: practiceSet.title,
                            clips: practiceSet.clips,
                            isFavorite: practiceSet.isFavorite
                        )
                        trackPracticeSets.append(updatedPracticeSet)
                        print("📦 [BundleManifestDriver] Added practice set '\(practiceSet.title ?? "Untitled")' (displayOrder: \(practiceSet.displayOrder), clips: \(practiceSet.clips.count))")
                    }
                } else {
                    print("📦 [BundleManifestDriver] No practice sets found for track '\(bundleTrack.title)'")
                }
                
                // Import transcripts
                let transcripts = bundleTrack.transcripts ?? []
                
                // Generate tags
                let tags = autoTagsForTrack(sourceType: .textbook, languageCode: bundleTrack.languageCode, fileExtension: fileExtension)
                
                // Create track
                let track = Track(
                    id: trackId,
                    packId: packId,
                    title: bundleTrack.title,
                    filename: filename,
                    localUrl: dest,
                    durationMs: durationMs,
                    languageCode: bundleTrack.languageCode,
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
