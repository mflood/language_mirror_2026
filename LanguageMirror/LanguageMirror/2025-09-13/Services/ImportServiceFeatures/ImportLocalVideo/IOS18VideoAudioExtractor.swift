//
//  IOS18VideoAudioExtractor.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingVideo/IOS18VideoAudioExtractor.swift
@preconcurrency import AVFoundation
import Foundation

public enum VideoImportError: Error {
    case exportSessionCreationFailed
    case exportFailed(underlying: Error?)
    case unsupportedFormat(String)
    case videoHasNoAudioTrack
    case fileSystemError(underlying: Error)
    
    var localizedDescription: String {
        switch self {
        case .exportSessionCreationFailed:
            return "Unable to create audio extractor for this video format"
        case .exportFailed(let error):
            return "Failed to extract audio: \(error?.localizedDescription ?? "unknown error")"
        case .unsupportedFormat(let format):
            return "Video format '\(format)' is not supported for audio extraction"
        case .videoHasNoAudioTrack:
            return "This video doesn't contain any audio tracks"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        }
    }
}

public final class IOS18VideoAudioExtractor: VideoAudioExtractorProtocol {
    public init() {}

    public func extractAudio(from videoURL: URL, progress: (@Sendable (Float) -> Void)?) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        
        // Check if video has audio tracks
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw VideoImportError.videoHasNoAudioTrack
        }
        
        guard let exporter = AVAssetExportSession(asset: asset,
                                                  presetName: AVAssetExportPresetAppleM4A) else {
            throw VideoImportError.exportSessionCreationFailed
        }
        let outURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString + ".m4a")

        // Set up progress observation if callback provided
        var progressObserver: NSKeyValueObservation?
        if let progress = progress {
            progressObserver = exporter.observe(\.progress, options: [.new]) { _, change in
                if let newValue = change.newValue {
                    progress(Float(newValue))
                }
            }
        }

        return try await withTaskCancellationHandler(
            operation: { [exporter] in
                do {
                    try await exporter.export(to: outURL, as: .m4a)
                    return outURL
                } catch {
                    throw VideoImportError.exportFailed(underlying: error)
                }
            },
            onCancel: {
                [weak exporter] in
                    exporter?.cancelExport()
            }
        )
    }
}
