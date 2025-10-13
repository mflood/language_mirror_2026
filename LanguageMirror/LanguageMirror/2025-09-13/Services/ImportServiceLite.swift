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
    private let library: LibraryService
    private let segmentService: SegmentService
    
    
    private let videoUseCase: ImportVideoUseCase
    private let remoteUseCase: ImportRemoteUseCase
    private let audioUseCase: ImportAudioUseCase
    private let importEmbeddedSampleDriver: ImportEmbeddedSampleDriver
    private let recordingUseCase: ImportRecordingUseCase
    
    /// Optional hook the VC can pass in to show alerts.
    /// Signature: (title, message)
    
    init(library: LibraryService, segments: SegmentService, useMock: Bool) {
        self.library = library
        self.segmentService = segments
        
        self.videoUseCase = ImportVideoUseCase(
            engine: VideoImporterFactory.make(useMock: useMock),
            library: library
        )
        
        self.remoteUseCase = ImportRemoteUseCase(
            engine: RemoteImporterFactory.make(useMock: useMock),
            library: library
        )
        
        self.audioUseCase  = ImportAudioUseCase(engine: AudioImporterFactory.make(
            useMock: useMock),
                                                library: library)
        
        self.importEmbeddedSampleDriver  = ImportEmbeddedSampleDriver(
                                                  engine: SampleImporterFactory.make(),
                                                  library: library,
                                                  segments: segmentService)
        
        self.recordingUseCase = ImportRecordingUseCase(engine: RecordingImporterFactory.make(),
                                                       library: library)
    }

    // Only supports .videoFile; others alert + throw
    func performImport(source: ImportSource) async throws -> [Track] {
        try Task.checkCancellation()
        
        for track in self.library.listTracks(in: nil) {
            print("Track: \(track.title) (\(track.filename))")
        }
            
        switch source {
        case .videoFile(let url):
            return try await videoUseCase.run(videoURL: url, suggestedTitle: nil)

        case .remoteURL(let url, let suggestedTitle):
            return try await remoteUseCase.run(url: url, suggestedTitle: suggestedTitle)
            
        case .audioFile(let url):
            return try await audioUseCase.run(sourceURL: url, suggestedTitle: nil)

        case .embeddedSample:
            
            let newTracks = try await importEmbeddedSampleDriver.run()
            return newTracks
            
        case .recordedFile(let url):
            let title = "Recording \(Date().formatted())"
            return try await recordingUseCase.run(sourceURL: url, title: title)
            
        case .bundleManifest:
            throw ImportLiteError.notImplemented
        }
    }
}
