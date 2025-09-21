//
//  IOS18AudioImporter.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingAudio/IOS18AudioImporter.swift
import Foundation

public enum LocalAudioImportError: Error {
    case notFound
    case unreadable
}

public final class IOS18AudioImporter: AudioImporting {
    public init() {}

    public func prepareLocalAudio(from url: URL) async throws -> URL {
        try Task.checkCancellation()
        // Minimal validation; you could add UTI/MIME checks if needed.
        guard FileManager.default.fileExists(atPath: url.path) else { throw LocalAudioImportError.notFound }
        // You might copy to a temp URL here if you want to break any file bookmarks.
        return url
    }
}
