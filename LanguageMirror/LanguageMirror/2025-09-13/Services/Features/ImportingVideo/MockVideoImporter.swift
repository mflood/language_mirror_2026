//
//  MockVideoImporter.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

import Foundation

/// A controllable mock:
/// - returns `sample.mp3` from the main bundle
/// - can take a configurable duration (sleep in small steps, cancellable)
/// - can throw a configured error (immediately or after the delay)
public final class MockVideoImporter: VideoImporting {

    public enum ErrorMode: Sendable {
        case none
        case immediate(Error)       // throws right away
        case afterDelay(Error)      // throws after sleeping
    }

    private let totalDuration: TimeInterval
    private let step: TimeInterval
    private let errorMode: ErrorMode

    /// - Parameters:
    ///   - totalDuration: total time to “process” in seconds (default 0 = instant)
    ///   - step: sleep granularity in seconds (default 0.2s). Smaller steps = more responsive cancel.
    ///   - errorMode: .none, .immediate, or .afterDelay(SomeError)
    public init(totalDuration: TimeInterval = 0,
                step: TimeInterval = 0.2,
                errorMode: ErrorMode = .none) {
        self.totalDuration = max(0, totalDuration)
        self.step = max(0.01, step)
        self.errorMode = errorMode
    }

    public func extractAudio(from videoURL: URL) async throws -> URL {
        switch errorMode {
        case .immediate(let err):
            throw err
        case .none, .afterDelay:
            break
        }

        // Sleep in small cancellable chunks
        if totalDuration > 0 {
            var elapsed: TimeInterval = 0
            while elapsed < totalDuration {
                try Task.checkCancellation()
                let chunk = min(step, totalDuration - elapsed)
                try await Task.sleep(nanoseconds: UInt64(chunk * 1_000_000_000))
                elapsed += chunk
            }
        }

        if case .afterDelay(let err) = errorMode {
            throw err
        }

        // Return the local sample from main bundle
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "mp3") else {
            throw VideoImportError.exportFailed
        }
        return url
    }
}
