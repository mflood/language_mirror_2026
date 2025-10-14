//
//  IOS18VideoImporter.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingVideo/IOS18VideoImporter.swift
@preconcurrency import AVFoundation
import Foundation

public enum VideoImportError: Error { case exportFailed }

public final class IOS18VideoImporter: VideoImporting {
    public init() {}

    public func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVAsset(url: videoURL)
        guard let exporter = AVAssetExportSession(asset: asset,
                                                  presetName: AVAssetExportPresetAppleM4A) else {
            throw VideoImportError.exportFailed
        }
        let outURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString + ".m4a")

        return try await withTaskCancellationHandler(
            operation: {
                try await exporter.export(to: outURL, as: .m4a)
                return outURL
            },
            onCancel: { exporter.cancelExport() }
        )
    }
}
