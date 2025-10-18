//
//  EmbeddedBundleManifestLoader.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

import Foundation

public protocol EmbeddedBundleManifestLoader: Sendable {
    /// Load the list of available embedded packs
    func loadAvailablePacks() async throws -> [EmbeddedPackMetadata]
    
    /// Load a specific pack by its ID
    func loadPack(packId: String) async throws -> EmbeddedBundlePack
    
    /// Locate the embedded sample assets in the main bundle.
    /// Returns the audio file URL, plus an optional manifest URL for segments.
    /// @deprecated Use loadAvailablePacks() and loadPack(packId:) instead
    func loadEmbeddedSample() async throws -> EmbeddedBundleManifest
}
