//
//  LibraryServiceJSON.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//
// path: Services/LibraryServiceJSON.swift
import Foundation
import AVFoundation

final class LibraryServiceJSON: LibraryService {
    private let fm = FileManager.default
    private let base: URL
    private let indexURL: URL

    private struct Index: Codable { var tracks: [Track] = [] }

    private var cache: Index = .init()

    init() {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        base = docs.appendingPathComponent("LanguageMirror/library", isDirectory: true)
        indexURL = base.appendingPathComponent("library.json")

        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        loadIndex()
    }

    private func loadIndex() {
        
        do {
            let data = try Data(contentsOf: indexURL)
            do {
                let idx = try JSONDecoder().decode(Index.self, from: data)
                cache = idx
            } catch {
                print("Library index decode failed: \(error)")
                cache = .init()
                saveIndex()
            }
        } catch {
            print("Library index load failed: \(error)")
            cache = .init()
            saveIndex()
        }
    }

    private func saveIndex() {
        do {
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cache)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            print("Library index save failed: \(error)")
        }
    }

    func listTracks(in group: String?) -> [Track] { cache.tracks }

    func loadTrack(id: String) throws -> Track {
        guard let t = cache.tracks.first(where: { $0.id == id }) else { throw LibraryError.notFound }
        return t
    }

    func addTrack(_ track: Track) throws {
        guard !cache.tracks.contains(where: { $0.id == track.id }) else {
            try updateTrack(track); return
        }
        cache.tracks.append(track)
        saveIndex()
        // Removed Notification from here and moved it into the importer view
    }

    func updateTrack(_ track: Track) throws {
        guard let idx = cache.tracks.firstIndex(where: { $0.id == track.id }) else { throw LibraryError.notFound }
        cache.tracks[idx] = track
        saveIndex()
        NotificationCenter.default.post(name: .LibraryDidChange, object: nil)
    }

    // Utilities to help importers (public static helpers are OK too)
    func trackFolder(forPackId packId: String, forTrackId trackId: String) -> URL {
        base.appendingPathComponent("packs/\(packId)/tracks/\(trackId)", isDirectory: true)
    }
}
