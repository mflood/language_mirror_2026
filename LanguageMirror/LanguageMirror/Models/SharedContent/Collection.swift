//
//  Collection.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//

import Foundation

struct Collection: Codable, Hashable {
    let id: UUID
    var name: String                  // "Korean Made Simple – Book 1"
    var groupOrder: [String]         // ["Intro", "Chapter 1", "Chapter 2", ...]
}
