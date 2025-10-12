//
//  ImportService.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/16/25.
//

import Foundation
import AVFoundation
import UniformTypeIdentifiers

enum ImportSource {
    case audioFile(url: URL)                          // from Files / Voice Memos
    case videoFile(url: URL)                          // from Photos picker export or Files
    case recordedFile(url: URL)                       // local recorder tmp
    case remoteURL(url: URL, suggestedTitle: String?) // direct URL download
    case bundleManifest(url: URL)                     // S3 manifest
    case embeddedSample                                // free sample in app
}

struct BundleManifest: Codable {
    let title: String
    let packs: [BundlePack]
}

struct BundlePack: Codable {
    let id: String?
    let title: String
    let author: String?
    let coverUrl: String?         // remote image URL
    let coverFilename: String?    // desired filename; default from url
    let tracks: [BundleTrack]
}

struct BundleTrack: Codable {
    let id: String?
    let title: String
    let url: String?               // remote audio URL
    let filename: String?          // desired filename; default from url
    let durationMs: Int?
    let segments: SegmentMap?      // optional built-in segments
}


public struct EmbeddedBundleManifest: Codable {
    let title: String
    let packs: [EmbeddedBundlePack]
}

struct EmbeddedBundlePack: Codable {
    let id: String?
    let title: String
    let author: String?
    let filename: String?    // name of cover image in bundle
    let tracks: [EmbeddedBundleTrack]
}

struct EmbeddedBundleTrack: Codable {
    let id: String?
    let title: String
    let filename: String          // name of audio file in bundle
    let durationMs: Int?
    let segments: SegmentMap?      // optional built-in segments
    
    func splitFilename() -> (name: String, ext: String) {
        let name = (filename as NSString).deletingPathExtension
        var ext = (filename as NSString).pathExtension
        if ext.isEmpty { ext = "m4a" }
        return (name, ext)
    }
}

protocol OldImportService: AnyObject {
    /// Import a source. Returns created/updated Track ids.
    func performImport(
            source: ImportSource,
            completion: @escaping (Result<[Track], Error>) -> Void)
}

protocol ImportService: AnyObject {
    func performImport(source: ImportSource) async throws -> [Track]
}



