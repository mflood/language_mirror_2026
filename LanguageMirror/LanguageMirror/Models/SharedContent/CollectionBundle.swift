//
//  CollectionBundle.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//


import Foundation

struct CollectionBundle: Codable {
    var collection: Collection
    var memberships: [TrackMembership]
    var tracks: [TrackBundle]
}
