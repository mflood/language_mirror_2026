//
//  DataManager.swift
//  LanguageMirror
//
//  Loads shared content (collections, tracks, arrangements, slices)
//  from `Resources/data.json`, OR from injected mock bundles.
//

import Foundation

final class DataManager {

    static let shared = DataManager()

    private(set) var collections: [Collection] = []
    private var membershipsByCollection = [UUID: [TrackMembership]]()
    private var trackMap = [UUID: AudioTrack]()
    private var arrangementsByTrack = [UUID: [Arrangement]]()
    private var slicesByArrangement = [UUID: [Slice]]()

    private(set) var isLoaded: Bool = false

    private init() {}

    init(mock bundles: [CollectionBundle]) {
        ingest(bundles)
        isLoaded = true
    }

    func load() throws {
        guard !isLoaded else { return }
        guard let url = Bundle.main.url(forResource: "data", withExtension: "json") else {
            throw NSError(domain: "DataManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "data.json not found in bundle"])
        }
        let bytes = try Data(contentsOf: url)
        let bundles = try JSONDecoder().decode([CollectionBundle].self, from: bytes)
        ingest(bundles)
        isLoaded = true
    }
    
    /// Mock loader for UI development / previews.
    func loadMock() {
        guard !isLoaded else { return }
        let bundles = MockDataLoader.demoBundles()
        if let typed = bundles as? [CollectionBundle] {
            ingest(typed)
            isLoaded = true
        } else {
            print("⚠️ MockDataLoader returned unexpected type")
        }
    }

    func memberships(for collectionId: UUID) -> [TrackMembership] {
        membershipsByCollection[collectionId] ?? []
    }

    func track(for id: UUID) -> AudioTrack? {
        trackMap[id]
    }

    func arrangements(for trackId: UUID) -> [Arrangement] {
        arrangementsByTrack[trackId] ?? []
    }

    func slices(for arrangementId: UUID) -> [Slice] {
        slicesByArrangement[arrangementId] ?? []
    }

    func url(for track: AudioTrack) -> URL {
        Bundle.main.url(forResource: track.fileURL.deletingSuffix(".mp3"), withExtension: "mp3") ?? URL(fileURLWithPath: "/dev/null")
    }

    func groupSections(for collection: Collection) -> [(title: String, tracks: [AudioTrack])] {
        let memberships = memberships(for: collection.id)
        var groups = Dictionary(grouping: memberships) { $0.group ?? "_unclassified" }
        var result: [(String, [AudioTrack])] = []

        for g in collection.groupOrder {
            if let ms = groups.removeValue(forKey: g) {
                result.append((g, ms.compactMap { track(for: $0.trackId) }))
            }
        }

        if let un = groups.removeValue(forKey: "_unclassified") {
            result.append(("Unclassified", un.compactMap { track(for: $0.trackId) }))
        }

        for (g, ms) in groups.sorted(by: { $0.key < $1.key }) {
            result.append((g, ms.compactMap { track(for: $0.trackId) }))
        }

        return result
    }

    private func ingest(_ bundles: [CollectionBundle]) {
        collections.removeAll()
        membershipsByCollection.removeAll()
        trackMap.removeAll()
        arrangementsByTrack.removeAll()
        slicesByArrangement.removeAll()

        for cb in bundles {
            let col = cb.collection
            collections.append(col)
            membershipsByCollection[col.id] = cb.memberships

            for tb in cb.tracks {
                trackMap[tb.track.id] = tb.track
                arrangementsByTrack[tb.track.id] = tb.arrangements.map(\.arrangement)
                for ab in tb.arrangements {
                    slicesByArrangement[ab.arrangement.id] = ab.slices
                }
            }
        }
    }
}

private extension String {
    func deletingSuffix(_ suffix: String) -> String {
        guard hasSuffix(suffix) else { return self }
        return String(dropLast(suffix.count))
    }
}
