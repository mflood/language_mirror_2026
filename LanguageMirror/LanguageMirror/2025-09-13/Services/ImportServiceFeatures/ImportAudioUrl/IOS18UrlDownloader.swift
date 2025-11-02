//
//  IOS18UrlDownloader.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingRemote/IOS18UrlDownloader.swift
import Foundation

public enum RemoteImportError: Error {
    case notAudio
    case httpStatus(Int)
}
// IOS18UrlDownloader.swift

public final class IOS18UrlDownloader: UrlDownloaderProtocol {
    public init() {}

    public func downloadAudio(from url: URL) async throws -> (url: URL, suggestedFilename: String) {
        // Validate URL scheme before attempting download
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw URLError(.unsupportedURL)
        }
        
        // Defensive check: warn if this looks like a JSON/manifest URL
        let pathExtension = url.pathExtension.lowercased()
        if pathExtension == "json" {
            print("⚠️ [IOS18UrlDownloader] WARNING: Attempting to download audio from URL ending in .json")
            print("⚠️ [IOS18UrlDownloader] URL: \(url.absoluteString)")
            print("⚠️ [IOS18UrlDownloader] JSON files should NOT be processed through downloadAudio()")
            print("⚠️ [IOS18UrlDownloader] This likely indicates a routing bug - JSON manifests should use NetworkSession directly")
        }
        
        // Auto-cancellable with Task cancellation
        let (tmpURL, response) = try await NetworkSession.shared.download(from: url)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RemoteImportError.httpStatus(http.statusCode)
        }
        // Optional: basic MIME sniff (helpful but not required)
        // If you want stricter checks, do a HEAD first or inspect Content-Type header.

        print("Downloaded to temp URL: \(tmpURL)")
        print("suggested filename: \(response.suggestedFilename ?? "unknown")")
        
        let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg", "opus"]
        
        if let filename = response.suggestedFilename?.lowercased() {
            print("🔍 [IOS18UrlDownloader] Checking filename: \(filename)")
            if !audioExtensions.contains(where: { filename.hasSuffix($0) }) {
                print("❌ [IOS18UrlDownloader] File extension not in allowed list. Extensions: \(audioExtensions)")
                print("❌ [IOS18UrlDownloader] This URL should NOT be processed by IOS18UrlDownloader - it's not an audio file!")
                
                // Additional logging for JSON files
                if filename.hasSuffix(".json") || pathExtension == "json" {
                    print("❌ [IOS18UrlDownloader] ERROR: JSON file was incorrectly routed to audio downloader!")
                    print("❌ [IOS18UrlDownloader] Original URL: \(url.absoluteString)")
                    print("❌ [IOS18UrlDownloader] Suggested filename: \(filename)")
                    print("❌ [IOS18UrlDownloader] This is a bug - JSON manifests must use NetworkSession.shared.download(), not urlDownloader.downloadAudio()")
                }
                
                throw RemoteImportError.notAudio
            }
            print("✅ [IOS18UrlDownloader] Audio file validated")
            return (url: tmpURL, suggestedFilename: filename)
        } else {
            print("⚠️ [IOS18UrlDownloader] No suggested filename, inferring from URL")
            let ext = (url.pathExtension.isEmpty ? "m4a" : url.pathExtension)
            print("🔍 [IOS18UrlDownloader] Inferred extension: \(ext)")
            if !audioExtensions.contains(ext.lowercased()) {
                print("❌ [IOS18UrlDownloader] Inferred extension '\(ext)' not in allowed list")
                
                // Additional logging for JSON files
                if ext.lowercased() == "json" {
                    print("❌ [IOS18UrlDownloader] ERROR: JSON file was incorrectly routed to audio downloader!")
                    print("❌ [IOS18UrlDownloader] Original URL: \(url.absoluteString)")
                    print("❌ [IOS18UrlDownloader] Inferred extension: \(ext)")
                    print("❌ [IOS18UrlDownloader] This is a bug - JSON manifests must use NetworkSession.shared.download(), not urlDownloader.downloadAudio()")
                }
                
                throw RemoteImportError.notAudio
            }
            return (url: tmpURL, suggestedFilename: "audio.\(ext)")
        }
    }
}
