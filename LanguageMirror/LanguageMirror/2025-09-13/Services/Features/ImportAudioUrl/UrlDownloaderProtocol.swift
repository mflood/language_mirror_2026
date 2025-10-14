//
//  UrlDownloaderProtocol.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingRemote/UrlDownloaderProtocol.swift
import Foundation

public protocol UrlDownloaderProtocol: Sendable {
    /// Downloads an audio file and returns a temporary local URL.
    func downloadAudio(from url: URL) async throws -> (url: URL, suggestedFilename: String)
}
