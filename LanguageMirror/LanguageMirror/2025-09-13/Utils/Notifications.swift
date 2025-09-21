//
//  Notifications.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/16/25.
//

import Foundation

extension Notification.Name {
    static let LibraryDidChange = Notification.Name("LibraryDidChange")
}

extension Notification.Name {
    static let libraryDidAddTrack = Notification.Name("libraryDidAddTrack")
}

// We can use this to store notifications tokens in classes that are marked
// as MainActor, since properties in MainActor classes cannot be
// non-isolated.  Otherwise we run into issues when removing the observer
// during deinit.
final class NotificationTokenBox {
    var token: NSObjectProtocol?
}
