//
//  AudioImporterFactory.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingAudio/AudioImporterFactory.swift
import Foundation

public enum AudioImporterFactory {
    public static func make(useMock: Bool = false) -> AudioImporting {
        #if DEBUG
        if useMock {
            return MockAudioImporter(totalDuration: 1.5, step: 0.1, errorMode: .none)
        }
        #endif
        return IOS18AudioImporter()
    }
}
