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

    private struct Index: Codable { 
        var packs: [Pack] = []
        
        func allTracks() -> [Track] { packs.flatMap(\.tracks) }
        func nonEmptyPacks() -> [Pack] { packs.filter { !$0.tracks.isEmpty } }
    }

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
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            do {
                let idx = try decoder.decode(Index.self, from: data)
                cache = idx
            } catch {
                // Try migrating from old format
                print("Library index decode failed, attempting migration: \(error)")
                if let migrated = try? migrateFromLegacyFormat(data: data) {
                    cache = migrated
                    saveIndex()
                } else {
                    cache = .init()
                    saveIndex()
                }
            }
        } catch {
            print("Library index load failed: \(error)")
            cache = .init()
            saveIndex()
        }
    }
    
    private func migrateFromLegacyFormat(data: Data) throws -> Index {
        // Try old format: { "tracks": [...] }
        struct LegacyIndex: Codable { var tracks: [Track] = [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let legacy = try decoder.decode(LegacyIndex.self, from: data)
        
        // Group tracks by packId into packs
        var packsDict: [String: Pack] = [:]
        for track in legacy.tracks {
            if var pack = packsDict[track.packId] {
                pack.tracks.append(track)
                packsDict[track.packId] = pack
            } else {
                let packTitle = packTitleForId(track.packId)
                packsDict[track.packId] = Pack(
                    id: track.packId,
                    title: packTitle,
                    languageHint: track.languageCode,
                    tracks: [track]
                )
            }
        }
        
        return Index(packs: Array(packsDict.values))
    }
    
    private func packTitleForId(_ id: String) -> String {
        switch id {
        case UUID.namespaceFromVideo.uuidString: return "Video Extracts"
        case UUID.namespaceFromMemo.uuidString: return "Audio Imports"
        case UUID.namespaceFromRecording.uuidString: return "Recordings"
        case UUID.namespaceDownloadedFile.uuidString: return "Downloaded Audio"
        default: return "Imported Pack"
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

    // MARK: - Pack Methods
    
    func listPacks() -> [Pack] {
        return cache.packs
    }
    
    func listNonEmptyPacks() -> [Pack] {
        return cache.nonEmptyPacks()
    }
    
    func loadPack(id: String) throws -> Pack {
        guard let pack = cache.packs.first(where: { $0.id == id }) else {
            throw LibraryError.notFound
        }
        return pack
    }
    
    func addPack(_ pack: Pack) throws {
        guard !cache.packs.contains(where: { $0.id == pack.id }) else {
            try updatePack(pack)
            return
        }
        cache.packs.append(pack)
        saveIndex()
    }
    
    func updatePack(_ pack: Pack) throws {
        guard let idx = cache.packs.firstIndex(where: { $0.id == pack.id }) else {
            throw LibraryError.notFound
        }
        cache.packs[idx] = pack
        saveIndex()
        NotificationCenter.default.post(name: .LibraryDidChange, object: nil)
    }
    
    // MARK: - Track Methods
    
    func listTracks(in packId: String) -> [Track] {
        guard let pack = cache.packs.first(where: { $0.id == packId }) else { return [] }
        return pack.tracks
    }
    
    func listTracks(in group: String?) -> [Track] { 
        return cache.allTracks()
    }

    func loadTrack(id: String) throws -> Track {
        guard let t = cache.allTracks().first(where: { $0.id == id }) else { 
            throw LibraryError.notFound 
        }
        return t
    }
    
    func addTrack(_ track: Track, to packId: String) throws {
        // Find or create pack
        if let packIdx = cache.packs.firstIndex(where: { $0.id == packId }) {
            // Check if track already exists
            if cache.packs[packIdx].tracks.contains(where: { $0.id == track.id }) {
                // Update existing track
                if let trackIdx = cache.packs[packIdx].tracks.firstIndex(where: { $0.id == track.id }) {
                    cache.packs[packIdx].tracks[trackIdx] = track
                }
            } else {
                // Add new track
                cache.packs[packIdx].tracks.append(track)
            }
        } else {
            // Create new pack
            let packTitle = packTitleForId(packId)
            let newPack = Pack(
                id: packId,
                title: packTitle,
                languageHint: track.languageCode,
                tracks: [track]
            )
            cache.packs.append(newPack)
        }
        saveIndex()
        NotificationCenter.default.post(name: .LibraryDidChange, object: nil)
    }

    func updateTrack(_ track: Track) throws {
        // Find the pack containing this track
        guard let packIdx = cache.packs.firstIndex(where: { $0.tracks.contains(where: { $0.id == track.id }) }),
              let trackIdx = cache.packs[packIdx].tracks.firstIndex(where: { $0.id == track.id }) else {
            throw LibraryError.notFound
        }
        cache.packs[packIdx].tracks[trackIdx] = track
        saveIndex()
        NotificationCenter.default.post(name: .LibraryDidChange, object: nil)
    }
    
    // MARK: - Practice Set Methods (stub implementations)
    
    func listPracticeSets(in trackId: String) -> [PracticeSet] {
        guard let track = try? loadTrack(id: trackId) else { return [] }
        return track.practiceSets
    }
    
    func loadPracticeSet(id: String) throws -> PracticeSet {
        throw LibraryError.notFound // Not implemented - practice sets are stored in track
    }
    
    func addPracticeSet(_ practiceSet: PracticeSet, to trackId: String) throws {
        throw LibraryError.notFound // Not implemented
    }
    
    func updatePracticeSet(_ practiceSet: PracticeSet, in trackId: String) throws {
        throw LibraryError.notFound // Not implemented
    }
    
    func deletePracticeSet(id: String, from trackId: String) throws {
        throw LibraryError.notFound // Not implemented
    }
    
    // MARK: - Clip Methods (stub implementations)
    
    func listClips(in practiceSetId: String) -> [Clip] {
        return [] // Not implemented - clips are stored in practice set
    }
    
    func loadClip(id: String) throws -> Clip {
        throw LibraryError.notFound // Not implemented
    }
    
    func addClip(_ clip: Clip, to practiceSetId: String) throws {
        throw LibraryError.notFound // Not implemented
    }
    
    func updateClip(_ clip: Clip, in practiceSetId: String) throws {
        throw LibraryError.notFound // Not implemented
    }
    
    func deleteClip(id: String, from practiceSetId: String) throws {
        throw LibraryError.notFound // Not implemented
    }

    // Utilities to help importers (public static helpers are OK too)
    func trackFolder(forPackId packId: String, forTrackId trackId: String) -> URL {
        base.appendingPathComponent("packs/\(packId)/tracks/\(trackId)", isDirectory: true)
    }
}
