//
//  ImportAudioUrlDriver.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingRemote/ImportAudioUrlDriver.swift
@preconcurrency import AVFoundation
import Foundation

public final class ImportAudioUrlDriver {
    private let urlDownloader: UrlDownloaderProtocol
    private let fm = FileManager.default
    private let library: LibraryService

    init(urlDownloader: UrlDownloaderProtocol, library: LibraryService) {
        self.urlDownloader = urlDownloader
        self.library = library
    }

    func run(url: URL, suggestedTitle: String?) async throws -> [Track] {
        try Task.checkCancellation()

        // 1) Download (temp URL)
        let (tempAudio, suggestedFilename) = try await urlDownloader.downloadAudio(from: url)
        try Task.checkCancellation()

        // 2) Persist

        //  id is UUID5 of the source URL
        let trackId = uuid5(namespace: UUID.namespaceDownloadedFile, name: norm(url.absoluteString)).uuidString
        
        guard let lib = library as? LibraryServiceJSON else { throw LibraryError.writeFailed }

        let folder = lib.trackFolder(forPackId: UUID.namespaceDownloadedFile.uuidString, forTrackId: trackId)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let dest = folder.appendingPathComponent(suggestedFilename)
        if fm.fileExists(atPath: tempAudio.path) {
            print("downloaded file still exists!!!")
        }
        
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.copyItem(at: tempAudio, to: dest)

        if fm.fileExists(atPath: tempAudio.path) {
            print("downloaded file still exists!!!")
        }
        
        if fm.fileExists(atPath: dest.path) {
            print("copied file exists too!")
        }
        
        var seconds: Double
        var ms: Int? = nil
        
        // 3) Duration (async KVC in iOS 18)
        do {
            print("reading duration of file at \(dest.path)")
            if fm.fileExists(atPath: dest.path) {
                print("file exists too!")
            }
            seconds = try await AVURLAsset(url: dest).load(.duration).seconds
            ms = Int((seconds.isFinite ? seconds : 0) * 1000.0)
            print("Duration in seconds: \(seconds)")
        } catch {
            print("Failed to load duration: \(error.localizedDescription)")
        }

        // 4) Save track
        let title = suggestedTitle ?? url.lastPathComponent
        
        let emptySegmentMap = SegmentMap.fullTrackFactory(trackId: trackId, displayOrder: 0)
        
        let track = Track(
            id: trackId,
            packId: UUID.namespaceDownloadedFile.uuidString,
            title: title,
            filename: suggestedFilename,
            localUrl: dest,
            durationMs: ms,
            segmentMaps: [emptySegmentMap],
            transcripts: [],
            // createdAt: Date(),
        )
            
        try library.addTrack(track)
        return [track]
    }
}
