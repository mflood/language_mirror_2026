//
//  IOS18RecordingImporter.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingRecording/IOS18RecordingImporter.swift
import Foundation

public enum RecordingImportError: Error {
    case notFound
    case unreadable
}

public final class IOS18RecordingImporter: RecordingImporting {
    public init() {}

    public func prepareRecordedAudio(from url: URL) async throws -> URL {
        try Task.checkCancellation()
        // Recorded files should be in your app sandbox already.
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RecordingImportError.notFound
        }
        return url
    }
}
