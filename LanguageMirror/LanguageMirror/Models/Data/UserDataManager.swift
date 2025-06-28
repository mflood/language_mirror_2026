    //
//  UserDataManager.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//

import Foundation


final class UserDataManager {

    static let shared = UserDataManager()
    private(set) var isLoaded = false

    private(set) var profile = UserProfile(
        id: UUID(),
        displayName: "",
        defaultLoopCount: 40,
        created: Date()
    )

    private var progressMap = [UUID: TrackProgress]()
    private var sessions = [StudySession]()

    private var fileURL: URL {
        let base = try! FileManager.default.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        let dir = base.appendingPathComponent("LanguageMirror", isDirectory: true)
        return dir.appendingPathComponent("userData.json")
    }

    private init() {}

    func load() throws {
        guard !isLoaded else { return }

        if let container = try Self.loadContainer(from: fileURL) {
            ingest(container)
        } else {
            profile = UserProfile(
                id: UUID(),
                displayName: "Learner",
                defaultLoopCount: 40,
                created: Date()
            )
            persist()
        }

        isLoaded = true
    }
    
    /// Fills manager with demo data (non‑persistent) for UI previews.
    func loadMock() {
        guard !isLoaded else { return }
        let profile = MockUserDataLoader.demoUserProfile()
        let progress = [MockUserDataLoader.demoTrackProgress(for: profile.id)]
        let session = [MockUserDataLoader.demoStudySession(userId: profile.id, trackId: UUID(), arrangementId: UUID())]
        ingest(UserContainer(profile: profile, progress: progress, sessions: session))
        isLoaded = true
    }

    func progress(for trackId: UUID) -> TrackProgress? {
        return progressMap[trackId]
    }

    func save(_ progress: TrackProgress) {
        progressMap[progress.trackId] = progress
        persist()
    }

    func log(session: StudySession) {
        sessions.append(session)
        persist()
    }

    private func persist() {
        let container = UserContainer(
            profile: profile,
            progress: Array(progressMap.values),
            sessions: sessions
        )
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(container)
            try data.write(to: fileURL)
        } catch {
            print("❌ UserData persist error: \(error)")
        }
    }

    private func ingest(_ container: UserContainer) {
        profile = container.profile
        progressMap = Dictionary(uniqueKeysWithValues: container.progress.map { ($0.trackId, $0) })
        sessions = container.sessions
    }

    private static func loadContainer(from url: URL) throws -> UserContainer? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try JSONDecoder().decode(UserContainer.self, from: data)
    }
}

