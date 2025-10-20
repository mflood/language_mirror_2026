//
//  app_container.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import Foundation

struct AppContainer {
    let practiceService: PracticeService
    let libraryService: LibraryService
    let audioPlayer: AudioPlayerService
    let clipService: ClipService
    let settings: SettingsService
    let importService: ImportService 

    init() {
        self.settings = SettingsServiceUserDefaults()
        self.practiceService = PracticeServiceJSON()
        self.libraryService = LibraryServiceJSON(practiceService: practiceService)
        self.audioPlayer = AudioPlayerServiceAVPlayer(practiceService: practiceService, settings: settings)
        self.clipService = ClipServiceJSON()
        self.importService = ImportServiceLite(library: libraryService,
                                               clips: clipService,
                                               useMock: false)
    }
}
