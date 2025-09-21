//
//  MockRecordingImporter.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//
// Features/ImportingRecording/MockRecordingImporter.swift
import Foundation

public final class MockRecordingImporter: RecordingImporting {
    public enum ErrorMode: Sendable {
        case none
        case immediate(Error)
        case afterDelay(Error)
    }

    private let totalDuration: TimeInterval
    private let step: TimeInterval
    private let errorMode: ErrorMode

    public init(totalDuration: TimeInterval = 0,
                step: TimeInterval = 0.2,
                errorMode: ErrorMode = .none) {
        self.totalDuration = max(0, totalDuration)
        self.step = max(0.01, step)
        self.errorMode = errorMode
    }

    public func prepareRecordedAudio(from url: URL) async throws -> URL {
        switch errorMode {
        case .immediate(let e): throw e
        case .none, .afterDelay: break
        }

        if totalDuration > 0 {
            var elapsed: TimeInterval = 0
            while elapsed < totalDuration {
                try Task.checkCancellation()
                let chunk = min(step, totalDuration - elapsed)
                try await Task.sleep(nanoseconds: UInt64(chunk * 1_000_000_000))
                elapsed += chunk
            }
        }

        if case .afterDelay(let e) = errorMode { throw e }

        guard let sample = Bundle.main.url(forResource: "sample", withExtension: "mp3") else {
            throw RecordingImportError.notFound
        }
        return sample
    }
}

