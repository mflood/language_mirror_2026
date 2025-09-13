//
//  app_container.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import Foundation

struct AppContainer {
    let libraryService: LibraryService

    init() {
        self.libraryService = LibraryServiceJSON()
    }
}
