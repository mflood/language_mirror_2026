//
//  IOS18RemoteImporter.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingRemote/IOS18RemoteImporter.swift
import Foundation

public enum RemoteImportError: Error {
    case notAudio
    case httpStatus(Int)
}

public final class IOS18RemoteImporter: RemoteImporting {
    public init() {}

    public func downloadAudio(from url: URL) async throws -> URL {
        // Auto-cancellable with Task cancellation
        let (tmpURL, response) = try await URLSession.shared.download(from: url)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RemoteImportError.httpStatus(http.statusCode)
        }
        // Optional: basic MIME sniff (helpful but not required)
        // If you want stricter checks, do a HEAD first or inspect Content-Type header.

        return tmpURL
    }
}
