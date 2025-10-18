//
//  IOS18SampleImporter.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingSample/IOS18SampleImporter.swift
import Foundation

public enum SampleImportError: Error {
    case notFound
    case unreadable
    case packNotFound(packId: String)
}

public final class IOS18SampleImporter: EmbeddedBundleManifestLoader {
    public init() {}
    
    public func loadAvailablePacks() async throws -> [EmbeddedPackMetadata] {
        print("Loading available embedded packs manifest...")
        
        guard let manifestUrl = Bundle.main.url(
            forResource: "packs_manifest",
            withExtension: "json",
            subdirectory: "embedded_packs"
        ) else {
            throw SampleImportError.notFound
        }
        
        let data = try Data(contentsOf: manifestUrl)
        let manifest = try JSONDecoder().decode(EmbeddedPacksManifest.self, from: data)
        
        print("Found \(manifest.packs.count) available packs:")
        for pack in manifest.packs {
            print("  - \(pack.title) (\(pack.trackCount) tracks)")
        }
        
        return manifest.packs
    }
    
    public func loadPack(packId: String) async throws -> EmbeddedBundlePack {
        print("Loading pack: \(packId)")
        
        // First, get the pack metadata to find the filename
        let availablePacks = try await loadAvailablePacks()
        
        guard let packMetadata = availablePacks.first(where: { $0.id == packId }) else {
            throw SampleImportError.packNotFound(packId: packId)
        }
        
        // Remove the .json extension to get the resource name
        let resourceName = (packMetadata.filename as NSString).deletingPathExtension
        
        guard let packUrl = Bundle.main.url(
            forResource: resourceName,
            withExtension: "json",
            subdirectory: "embedded_packs"
        ) else {
            throw SampleImportError.notFound
        }
        
        let data = try Data(contentsOf: packUrl)
        let pack = try JSONDecoder().decode(EmbeddedBundlePack.self, from: data)
        
        print("Loaded pack '\(pack.title)' with \(pack.tracks.count) tracks")
        
        return pack
    }

    public func loadEmbeddedSample() async throws -> EmbeddedBundleManifest {
        print("Loading embedded sample bundle manifest using IOS18SampleImporter (deprecated)...")
        
        guard let manifestUrl = Bundle.main.url(forResource: "sample_bundle", withExtension: "json") else {
           throw SampleImportError.notFound
        }
        
        if let data = try? Data(contentsOf: manifestUrl)
        {
            do {
                let mf = try JSONDecoder().decode(EmbeddedBundleManifest.self, from: data)
                print("Found \(mf.packs .count) packs in manifest:")
                for embeddedBundlePack in mf.packs {
                    print("Pack: \(embeddedBundlePack.title) with \(embeddedBundlePack.tracks.count) tracks")
                }
                    return mf
            } catch {
                print("Error decoding manifest: \(error)")
            }
        }

        throw SampleImportError.unreadable
    }
}
