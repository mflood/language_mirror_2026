//
//  Untitled.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//


import Foundation
// MARK: - Study Session Log  (mutable history item)
// MARK: - Study Session Log  (immutable history item)
struct StudySession: Codable, Hashable {
    let id: UUID
    let userId: UUID
    let trackId: UUID
    let arrangementId: UUID
    let started: Date
    let ended: Date
    let slicesCompleted: Int
    let totalLoops: Int
}
