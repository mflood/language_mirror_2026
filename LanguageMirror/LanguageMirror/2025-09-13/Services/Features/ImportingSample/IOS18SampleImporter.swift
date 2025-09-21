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
}

public final class IOS18SampleImporter: SampleImporting {
    public init() {}

    public func loadEmbeddedSample() async throws -> (audioURL: URL, manifestURL: URL?) {
        guard let audio = Bundle.main.url(forResource: "sample", withExtension: "mp3") else {
            throw SampleImportError.notFound
        }
        // Optional companion manifest for segments
        let manifest = Bundle.main.url(forResource: "sample_bundle", withExtension: "json")
        return (audioURL: audio, manifestURL: manifest)
    }
}
