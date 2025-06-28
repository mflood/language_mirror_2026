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

    func mockArrangements() -> [Arrangement] {
        [Arrangement(id: UUID(), name: "Sentence-Level"), Arrangement(id: UUID(), name: "Word-Level"), Arrangement(id: UUID(), name: "Full Track")]
    }

    func mockSlices() -> [Slice] {
        [
            Slice(id: UUID(), start: 0.0, end: 2.5, category: .learnable, transcript: "안녕하세요?"),
            Slice(id: UUID(), start: 2.5, end: 3.0, category: .noise, transcript: nil),
            Slice(id: UUID(), start: 3.0, end: 6.0, category: .learnable, transcript: "잘 지냈어요?")
        ]
    }
    
}
