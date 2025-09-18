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
