//
//  UserProfile.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//

import Foundation


struct UserProfile: Codable, Hashable {
    let id: UUID
    var displayName: String
    var defaultLoopCount: Int
    var created: Date
}

