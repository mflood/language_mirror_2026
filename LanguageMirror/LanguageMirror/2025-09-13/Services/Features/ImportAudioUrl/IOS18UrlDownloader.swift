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
        // Auto-cancellable with Task cancellation
        let (tmpURL, response) = try await URLSession.shared.download(from: url)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RemoteImportError.httpStatus(http.statusCode)
        }
        // Optional: basic MIME sniff (helpful but not required)
        // If you want stricter checks, do a HEAD first or inspect Content-Type header.

        print("Downloaded to temp URL: \(tmpURL)")
        print("suggested filename: \(response.suggestedFilename ?? "unknown")")
        
        if let filename = response.suggestedFilename?.lowercased() {
            let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg", "opus"]
            if !audioExtensions.contains(where: { filename.hasSuffix($0) }) {
                throw RemoteImportError.notAudio
            }
            return (url: tmpURL, suggestedFilename: filename)
        } else {
            let ext = (url.pathExtension.isEmpty ? "m4a" : url.pathExtension)
            return (url: tmpURL, suggestedFilename: "audio.\(ext)")
        }
    }
}
