//
//  SampleImporting.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

import Foundation

public protocol SampleImporting: Sendable {
    /// Locate the embedded sample assets in the main bundle.
    /// Returns the audio file URL, plus an optional manifest URL for segments.
    func loadEmbeddedSample() async throws -> EmbeddedBundleManifest
}
