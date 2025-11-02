//
//  ImportServiceLite.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//


import Foundation

// onCancel requires Sendable, but AVAssetExpoertSerssion is not Sendable yet, so
// this keeps the compiler happy for now:
@preconcurrency import AVFoundation
import UniformTypeIdentifiers


// MARK: - Errors
enum ImportLiteError: Error {
    case notImplemented
    case writeFailed
}

final class ImportServiceLite: ImportService {
    private let fm = FileManager.default
    let library: LibraryService  // Made internal to allow access from ImportViewController
    private let clipService: ClipService
    
    
    private let videoUseCase: ImportVideoDriver
    private let importAudioUrlDriver: ImportAudioUrlDriver
    private let audioUseCase: ImportAudioUseCase
    private let importEmbeddedSampleDriver: ImportEmbeddedSampleDriver
    private let recordingUseCase: ImportRecordingUseCase
    private let importBundleManifestDriver: ImportBundleManifestDriver
    
    /// Optional hook the VC can pass in to show alerts.
    /// Signature: (title, message)
    
    init(library: LibraryService, clips: ClipService, useMock: Bool) {
        self.library = library
        self.clipService = clips
        
        self.videoUseCase = ImportVideoDriver(
            engine: VideoImporterFactory.make(useMock: useMock),
            library: library
        )
        
        self.importAudioUrlDriver = ImportAudioUrlDriver(
            urlDownloader: UrlDownloaderFactory.make(useMock: useMock),
            library: library
        )
        
        self.audioUseCase  = ImportAudioUseCase(engine: AudioImporterFactory.make(
            useMock: useMock),
                                                library: library)
        
        self.importEmbeddedSampleDriver  = ImportEmbeddedSampleDriver(
                                                  engine: SampleImporterFactory.make(),
                                                  library: library,
                                                  clips: clipService)
        
        self.recordingUseCase = ImportRecordingUseCase(engine: RecordingImporterFactory.make(),
                                                       library: library)
        
        self.importBundleManifestDriver = ImportBundleManifestDriver(
            urlDownloader: UrlDownloaderFactory.make(useMock: useMock),
            library: library
        )
    }

    // Only supports .videoFile; others alert + throw
    func performImport(source: ImportSource, progress: (@Sendable (Float) -> Void)? = nil) async throws -> [Track] {
        try Task.checkCancellation()
            
        switch source {
        case .videoFile(let url):
            return try await videoUseCase.run(videoURL: url, suggestedTitle: nil, progress: progress)

        case .remoteURL(let url, let suggestedTitle):
            return try await importAudioUrlDriver.run(url: url, suggestedTitle: suggestedTitle)
            
        case .audioFile(let url):
            return try await audioUseCase.run(sourceURL: url, suggestedTitle: nil)

        case .embeddedSample:
            let newTracks = try await importEmbeddedSampleDriver.run()
            return newTracks
        
        case .embeddedPack(let packId):
            let newTracks = try await importEmbeddedSampleDriver.runSinglePack(packId: packId)
            return newTracks
            
        case .recordedFile(let url):
            let title = "Recording \(Date().formatted())"
            return try await recordingUseCase.run(sourceURL: url, title: title)
            
        case .bundleManifest(let url):
            // Bundle manifests support custom progress messages
            // We'll pass nil for progressMessage here since the protocol doesn't support it
            // ImportViewController will handle message updates directly
            return try await importBundleManifestDriver.run(manifestURL: url, progress: progress, progressMessage: nil)
        }
    }
}
