//
//  SharedImportModels.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 10/19/25.
//

import Foundation

/// Represents a pending import from the Share Extension
struct PendingImport: Codable {
    let id: String
    let fileURL: URL
    let timestamp: Date
    let sourceName: String?
    
    init(id: String = UUID().uuidString, 
         fileURL: URL, 
         timestamp: Date = Date(), 
         sourceName: String? = nil) {
        self.id = id
        self.fileURL = fileURL
        self.timestamp = timestamp
        self.sourceName = sourceName
    }
}

/// Container for pending imports queue
struct PendingImportsQueue: Codable {
    var imports: [PendingImport]
    
    init(imports: [PendingImport] = []) {
        self.imports = imports
    }
}

