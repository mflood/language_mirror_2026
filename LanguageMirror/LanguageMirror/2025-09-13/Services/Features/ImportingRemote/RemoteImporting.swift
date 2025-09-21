//
//  RemoteImporting.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingRemote/RemoteImporting.swift
import Foundation

public protocol RemoteImporting: Sendable {
    /// Downloads an audio file and returns a temporary local URL.
    func downloadAudio(from url: URL) async throws -> URL
}
