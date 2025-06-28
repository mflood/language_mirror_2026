//
//  AudioTrack.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//

import Foundation

struct AudioTrack: Hashable, Codable {
    let id: UUID
    var title: String
    var sourceType: AudioSourceType
    var fileURL: URL
    var duration: TimeInterval
}
