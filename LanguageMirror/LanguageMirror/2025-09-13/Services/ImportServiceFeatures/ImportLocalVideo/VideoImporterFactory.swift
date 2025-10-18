//
//  VideoImporterFactory.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingVideo/VideoImporterFactory.swift

public enum VideoImporterFactory {
    public static func make(useMock: Bool) -> VideoAudioExtractorProtocol {
        #if DEBUG
        if useMock {
            // Example: simulate a 3s job that can be cancelled
            return MockVideoAudioExtractor(totalDuration: 3.0, step: 0.1, errorMode: .none)
            // Or: MockVideoAudioExtractor(totalDuration: 2.0, errorMode: .afterDelay(VideoImportError.exportFailed))
            // Or: MockVideoAudioExtractor(errorMode: .immediate(VideoImportError.exportFailed))
        }
        #endif
        return IOS18VideoAudioExtractor()
    }
}
