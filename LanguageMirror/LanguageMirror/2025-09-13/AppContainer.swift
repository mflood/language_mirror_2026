//
//  app_container.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import Foundation

struct AppContainer {
    let libraryService: LibraryService
    let audioPlayer: AudioPlayerService
    let segmentService: SegmentService

    init() {
        self.libraryService = LibraryServiceJSON()
        self.audioPlayer = AudioPlayerServiceAVPlayer()
        self.segmentService = SegmentServiceJSON()
    }
}
