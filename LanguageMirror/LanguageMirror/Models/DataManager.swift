//
//  DataManager.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//


import Foundation

final class DataManager {
    static let shared = DataManager()
    private init() {}

    func loadTracks() -> [AudioTrack] {
        // Replace with JSON decode later
        let dummyURL = Bundle.main.url(forResource: "sample", withExtension: "mp3")!
        return [
            AudioTrack(id: UUID(), title: "Morning Dialogue",
                       sourceType: .textbook,
                       fileURL: dummyURL, duration: 12.5),
            AudioTrack(id: UUID(), title: "Voice Memo – Market",
                       sourceType: .voiceMemo,
                       fileURL: dummyURL, duration: 9.0)
        ]
    }
}
