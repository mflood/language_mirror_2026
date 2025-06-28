//
//  UserContainer.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//

import Foundation

struct UserContainer: Codable {
    var profile: UserProfile
    var progress: [TrackProgress]
    var sessions: [StudySession]
}
