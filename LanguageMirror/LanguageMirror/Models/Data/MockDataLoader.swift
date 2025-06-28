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
        
        
        let collId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let trackId = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let arrId   = UUID(uuidString: "a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1")!

        let collection = Collection(id: collId,
                                    name: "Demo Korean Collection",
                                    groupOrder: ["Intro", "Chapter 1"])

        let membership = TrackMembership(collectionId: collId,
                                         trackId: trackId,
                                         group: "Intro")

        let track = AudioTrack(id: trackId,
                               title: "Mock Dialogue",
                               sourceType: .textbook,
                               fileURL: "mock.mp3",
                               duration: 6.0,
                               tags: ["demo"])

        let arrangement = Arrangement(id: arrId, name: "Sentence‑Level")
        let slices: [Slice] = [
            Slice(id: UUID(), start: 0.0, end: 2.0, category: .learnable, transcript: "안녕하세요?"),
            Slice(id: UUID(), start: 2.0, end: 2.5, category: .noise, transcript: nil),
            Slice(id: UUID(), start: 2.5, end: 5.5, category: .learnable, transcript: "잘 지냈어요?")
        ]

        let arrBundle = ArrangementBundle(arrangement: arrangement, slices: slices)
        let trackBundle = TrackBundle(track: track, arrangements: [arrBundle])

        let bundle = CollectionBundle(collection: collection,
                                      memberships: [membership],
                                      tracks: [trackBundle])
        return [bundle]
    }
}
