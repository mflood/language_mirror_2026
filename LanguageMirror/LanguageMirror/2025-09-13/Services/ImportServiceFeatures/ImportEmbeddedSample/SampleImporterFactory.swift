//
//  SampleImporterFactory.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

import Foundation

public enum SampleImporterFactory {
    public static func make(useMock: Bool = false) -> EmbeddedBundleManifestLoader {
        #if DEBUG
        if useMock {
            return MockManifestLoader(totalDuration: 1.0, step: 0.1, errorMode: .none)
        }
        #endif
        return IOS18SampleImporter()
    }
}
