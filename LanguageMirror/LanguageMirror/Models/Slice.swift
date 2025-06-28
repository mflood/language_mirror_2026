//
//  Slice.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//


import Foundation

enum SliceType: String, Codable {
    case learnable, noise
}

struct Slice: Hashable, Codable {
    let id: UUID
    var start: TimeInterval
    var end: TimeInterval
    var category: SliceType
    var transcript: String?
}

