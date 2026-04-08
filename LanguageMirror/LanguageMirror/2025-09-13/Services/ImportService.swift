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
    case audioFile(url: URL)                            // from Files / Voice Memos
    case videoFile(url: URL)                            // from Photos picker export or Files
    case recordedFile(url: URL)                         // local recorder tmp
    case remoteURL(url: URL, suggestedTitle: String?)   // direct URL download
    case bundleManifest(url: URL)                       // S3 manifest
    case appBundleManifest(bundleId: String)            // bundle.json shipped inside the app's Resources
}

struct BundleManifest: Codable {
    /// Stable bundle identifier used for deterministic imports and publishing paths.
    /// Optional for backward compatibility with older manifests.
    let id: String?
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
    let languageCode: String?      // e.g. "ko-KR" | "en-US" | "zh-CN" | "es-ES"
    let practiceSets: [PracticeSet]?      // optional built-in clips
    let transcripts: [TranscriptSpan]?  // optional transcriptions
}


protocol OldImportService: AnyObject {
    /// Import a source. Returns created/updated Track ids.
    func performImport(
            source: ImportSource,
            completion: @escaping (Result<[Track], Error>) -> Void)
}

protocol ImportService: AnyObject {
    func performImport(source: ImportSource, progress: (@Sendable (Float) -> Void)?) async throws -> [Track]
}



