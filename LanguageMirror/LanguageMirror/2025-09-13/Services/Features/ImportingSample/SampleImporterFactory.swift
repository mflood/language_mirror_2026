//
//  SampleImporterFactory.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

import Foundation

public enum SampleImporterFactory {
    public static func make(useMock: Bool = false) -> SampleImporting {
        #if DEBUG
        if useMock {
            return MockSampleImporter(totalDuration: 1.0, step: 0.1, errorMode: .none)
        }
        #endif
        return IOS18SampleImporter()
    }
}
