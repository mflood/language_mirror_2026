//
//  VideoImporterFactory.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingVideo/VideoImporterFactory.swift

public enum VideoImporterFactory {
    public static func make(useMock: Bool) -> VideoImporting {
        #if DEBUG
        if useMock {
            // Example: simulate a 3s job that can be cancelled
            return MockVideoImporter(totalDuration: 3.0, step: 0.1, errorMode: .none)
            // Or: MockVideoImporter(totalDuration: 2.0, errorMode: .afterDelay(VideoImportError.exportFailed))
            // Or: MockVideoImporter(errorMode: .immediate(VideoImportError.exportFailed))
        }
        #endif
        return IOS18VideoImporter()
    }
}
