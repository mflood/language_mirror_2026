//
//  LibraryServiceJSON.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import Foundation

private struct LibraryStore: Codable {
    var packs: [Pack]
}

final class LibraryServiceJSON: LibraryService {
    private let fileURL: URL
    private var store: LibraryStore

    init() {
        // Documents/LanguageMirror/library.json
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir  = docs.appendingPathComponent("LanguageMirror", isDirectory: true)
        self.fileURL = dir.appendingPathComponent("library.json")

        do {
            self.store = try Self.loadOrSeed(at: fileURL)
        } catch {
            // As a last resort, start with an in-memory default to keep the app running.
            self.store = LibraryStore(packs: [
                Pack(id: "demo-pack", title: "Demo Pack", languageHint: "en-US", tracks: [
                    Track(id: "t1", title: "Greetings 01", filename: "sample.mp3", durationMs: 30000),
                    Track(id: "t2", title: "Greetings 02", filename: "sample.mp3", durationMs: 42000),
                    Track(id: "t3", title: "Dialog A",    filename: "sample.mp3", durationMs: 51000),
                ])
            ])
        }
    }

    func listPacks() -> [Pack] { store.packs }

    func listTracks(in packId: String?) -> [Track] {
        if let pid = packId, let pack = store.packs.first(where: { $0.id == pid }) {
            return pack.tracks
        }
        return store.packs.flatMap { $0.tracks }
    }

    func loadTrack(id: String) throws -> Track {
        for pack in store.packs {
            if let t = pack.tracks.first(where: { $0.id == id }) { return t }
        }
        throw LibraryError.notFound
    }

    func saveTrack(_ track: Track) throws {
        var saved = false
        for i in store.packs.indices {
            if let idx = store.packs[i].tracks.firstIndex(where: { $0.id == track.id }) {
                store.packs[i].tracks[idx] = track
                saved = true
                break
            }
        }
        if !saved, !store.packs.isEmpty {
            store.packs[0].tracks.append(track)
        }
        try persist()
    }

    // MARK: - I/O

    private func persist() throws {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(store)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw LibraryError.encodeError(error)
        }
    }

    private static func loadOrSeed(at fileURL: URL) throws -> LibraryStore {
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) {
            // Try to copy seed from bundle as "library_seed.json"
            if let seedURL = Bundle.main.url(forResource: "library_seed", withExtension: "json") {
                try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: seedURL, to: fileURL)
            } else {
                // Write a default seed if none provided
                let defaultStore = LibraryStore(packs: [
                    Pack(id: "demo-pack", title: "Demo Pack", languageHint: "en-US", tracks: [
                        Track(id: "t1", title: "Greetings 01", filename: "sample.mp3", durationMs: 30000),
                        Track(id: "t2", title: "Greetings 02", filename: "sample.mp3", durationMs: 42000),
                        Track(id: "t3", title: "Dialog A",    filename: "sample.mp3", durationMs: 51000),
                    ])
                ])
                try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let data = try JSONEncoder().encode(defaultStore)
                try data.write(to: fileURL, options: .atomic)
            }
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(LibraryStore.self, from: data)
        } catch {
            throw LibraryError.decodeError(error)
        }
    }
}
