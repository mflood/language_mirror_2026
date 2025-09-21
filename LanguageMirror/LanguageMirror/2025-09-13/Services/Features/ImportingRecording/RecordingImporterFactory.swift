//
//  RecordingImporterFactory.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingRecording/RecordingImporterFactory.swift
import Foundation

public enum RecordingImporterFactory {
    public static func make(useMock: Bool = false) -> RecordingImporting {
        #if DEBUG
        if useMock {
            return MockRecordingImporter(totalDuration: 1.0, step: 0.1, errorMode: .none)
        }
        #endif
        return IOS18RecordingImporter()
    }
}
