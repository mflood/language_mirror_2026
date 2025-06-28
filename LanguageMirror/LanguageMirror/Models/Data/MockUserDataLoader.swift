//
//  MockUserDataLoader.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//
// Supplies dummy user profiles, progress, and session
// history for previews or unit tests.
// -------------------------------------------------

import Foundation

struct MockUserDataLoader {
    static func demoUserProfile() -> UserProfile {
        
        return UserProfile(id: UUID(uuidString: "69586316-4827-4826-9E3E-4650C790F0D8")!,
                     displayName: "Demo Learner",
                     defaultLoopCount: 40,
                     created: Date())
    }

    
    static func demoTrackProgress(for trackId: UUID) -> TrackProgress {
        TrackProgress(trackId: trackId,
                      arrangementId: nil,
                      currentSliceIndex: 0,
                      loopsCompleted: 0,
                      customLoopCount: nil,
                      lastUpdated: Date())
    }

    static func demoStudySession(userId: UUID, trackId: UUID, arrangementId: UUID) -> StudySession {
        StudySession(id: UUID(),
                     userId: userId,
                     trackId: trackId,
                     arrangementId: arrangementId,
                     started: Date().addingTimeInterval(-600),
                     ended: Date(),
                     slicesCompleted: 6,
                     totalLoops: 40)
    }
}
