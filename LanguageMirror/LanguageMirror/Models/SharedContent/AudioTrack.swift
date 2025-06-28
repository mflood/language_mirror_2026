//
//  AudioTrack.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//

import Foundation


struct AudioTrack: Codable, Hashable {
    let id: UUID
    var title: String
    var sourceType: AudioSourceType
    var fileURL: String
    var duration: TimeInterval
    var tags: [String]
}
