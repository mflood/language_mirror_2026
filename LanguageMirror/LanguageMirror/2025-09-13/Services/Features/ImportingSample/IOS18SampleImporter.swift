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
}

public final class IOS18SampleImporter: SampleImporting {
    public init() {}

    public func loadEmbeddedSample() async throws -> EmbeddedBundleManifest {

        print("Loading embedded sample bundle manifest using IOS18SampleImporter...")
        
        guard let manifestUrl = Bundle.main.url(forResource: "sample_bundle", withExtension: "json") else {
           throw SampleImportError.notFound
        }
        
        if let data = try? Data(contentsOf: manifestUrl),
           let mf = try? JSONDecoder().decode(EmbeddedBundleManifest.self, from: data) {
            print("Found \(mf.packs .count) packs in manifest:")
            for embeddedBundlePack in mf.packs {
                print("Pack: \(embeddedBundlePack.title) with \(embeddedBundlePack.tracks.count) tracks")
            }
            return mf
        }

        throw SampleImportError.unreadable
    }
}
