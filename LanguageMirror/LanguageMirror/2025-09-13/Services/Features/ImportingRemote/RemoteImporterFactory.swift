//
//  RemoteImporterFactory.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

import Foundation

public enum RemoteImporterFactory {
    public static func make(useMock: Bool = false) -> RemoteImporting {
        #if DEBUG
        if useMock {
            return MockRemoteImporter(totalDuration: 2.0, step: 0.1, errorMode: .none)
        }
        #endif
        return IOS18RemoteImporter()
    }
}
