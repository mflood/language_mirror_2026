//
//  IOS18VideoAudioExtractor.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingVideo/IOS18VideoAudioExtractor.swift
@preconcurrency import AVFoundation
import Foundation

public enum VideoImportError: Error { case exportFailed }

public final class IOS18VideoAudioExtractor: VideoAudioExtractorProtocol {
    public init() {}

    public func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        guard let exporter = AVAssetExportSession(asset: asset,
                                                  presetName: AVAssetExportPresetAppleM4A) else {
            throw VideoImportError.exportFailed
        }
        let outURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString + ".m4a")

        return try await withTaskCancellationHandler(
            operation: { [exporter] in
                do {
                            print("\(exporter)")
                            try await exporter.export(to: outURL, as: .m4a)
                            return outURL
                        } catch {
                            print("Export failed: \(error.localizedDescription)")
                            throw error // re-throw the error after logging
                        }
            },
            onCancel: {
                [weak exporter] in
                    exporter?.cancelExport()
            }
        )
    }
}
