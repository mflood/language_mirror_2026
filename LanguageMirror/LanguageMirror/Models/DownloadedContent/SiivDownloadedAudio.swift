//
//  SiivDownloadedAudio.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/29/25.
//

import Foundation


// MARK: - Data Models
struct SiivDownloadedAudio {
    let id: String
    let name: String
    let url: String
    let downloadDate: Date
    let fileSize: String
    let duration: TimeInterval
}
