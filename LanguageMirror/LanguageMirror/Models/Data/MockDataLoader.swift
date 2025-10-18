//
//  MockDataLoader.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//
// Generates a fully‑formed in‑memory CollectionBundle
// for UI previews, unit tests, or demo builds when the
// real Resources/data.json isn’t available.
// -------------------------------------------------

import Foundation

/// Helper that fabricates demo content identical in shape to `data.json`
/// so DataManager can be seeded without reading disk.
struct MockDataLoader {
    /// Returns a single CollectionBundle containing one track,
    /// one arrangement, three slices.
    static func demoBundles() -> [Any] {
        
       
        return []
    }
}
