//
//  ImportRemoteUseCase.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingRemote/ImportRemoteUseCase.swift
@preconcurrency import AVFoundation
import Foundation

public final class ImportRemoteUseCase {
    private let engine: RemoteImporting
    private let fm = FileManager.default
    private let library: LibraryService

    init(engine: RemoteImporting, library: LibraryService) {
        self.engine = engine
        self.library = library
    }

    func run(url: URL, suggestedTitle: String?) async throws -> [Track] {
        try Task.checkCancellation()

        // 1) Download (temp URL)
        let tempAudio = try await engine.downloadAudio(from: url)
        try Task.checkCancellation()

        // 2) Persist
        let id = UUID().uuidString
        let ext = (tempAudio.pathExtension.isEmpty ? "m4a" : tempAudio.pathExtension)
        let filename = "audio.\(ext)"
        guard let lib = library as? LibraryServiceJSON else { throw LibraryError.writeFailed }

        let folder = lib.trackFolder(for: id)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let dest = folder.appendingPathComponent(filename)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.copyItem(at: tempAudio, to: dest)

        // 3) Duration (async KVC in iOS 18)
        let seconds = try await AVURLAsset(url: dest).load(.duration).seconds
        let ms = Int((seconds.isFinite ? seconds : 0) * 1000.0)

        // 4) Save track
        let title = suggestedTitle ?? url.lastPathComponent
        let track = Track(id: id, title: title, filename: filename, durationMs: ms)
        try library.addTrack(track)
        return [track]
    }
}
