//
//  AudioLocator.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//

// path: Utils/AudioLocator.swift
import Foundation

enum AudioLocator {
    static func resolveURL(for track: Track) -> URL? {
        let filename = track.filename
        let ext = (filename as NSString).pathExtension
        let base = (filename as NSString).deletingPathExtension

        // 1) Bundle
        if !base.isEmpty, let u = Bundle.main.url(forResource: base, withExtension: ext.isEmpty ? nil : ext) {
            return u
        }
        // 2) Documents/LanguageMirror/library/tracks/<track.id>/<filename>
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let inTrackDir = docs
                .appendingPathComponent("LanguageMirror", isDirectory: true)
                .appendingPathComponent("library", isDirectory: true)
                .appendingPathComponent("tracks", isDirectory: true)
                .appendingPathComponent(track.id, isDirectory: true)
                .appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: inTrackDir.path) { return inTrackDir }

            let inDocs = docs.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: inDocs.path) { return inDocs }
        }
        return nil
    }
}
