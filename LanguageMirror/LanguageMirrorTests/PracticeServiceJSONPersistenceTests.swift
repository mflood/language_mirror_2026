//
//  PracticeServiceJSONPersistenceTests.swift
//  LanguageMirrorTests
//
//  Round-trip tests for PracticeServiceJSON persistence. Guards the fix that
//  made saveSession / deleteSession synchronous and error-propagating —
//  previously fire-and-forget `ioQueue.async` that caught write errors inside
//  the closure and reported false success. Uses unique ids so it never
//  collides with real app data, and cleans up after itself.
//

import XCTest
@testable import LanguageMirror

final class PracticeServiceJSONPersistenceTests: XCTestCase {

    private var svc: PracticeServiceJSON!
    private var packId = ""
    private var trackId = ""

    override func setUp() {
        super.setUp()
        svc = PracticeServiceJSON()
        packId = "test_pack_\(UUID().uuidString)"
        trackId = "test_track_\(UUID().uuidString)"
    }

    override func tearDown() {
        try? svc.deleteSession(packId: packId, trackId: trackId)
        svc = nil
        super.tearDown()
    }

    private func makeSession() -> PracticeSession {
        PracticeSession(practiceSetId: "set_\(UUID().uuidString)",
                        packId: packId, trackId: trackId)
    }

    func testSaveThenLoadRoundTrips() throws {
        var session = makeSession()
        session.currentClipIndex = 4
        session.currentLoopCount = 2
        session.currentSpeed = 0.9
        session.clipPlayCounts = ["clipA": 3, "clipB": 1]
        session.foreverMode = true

        try svc.saveSession(session)   // synchronous write

        let loaded = try XCTUnwrap(svc.loadSession(packId: packId, trackId: trackId))
        // Everything but lastUpdatedAt (stamped by save) round-trips exactly.
        XCTAssertEqual(loaded.id, session.id)
        XCTAssertEqual(loaded.currentClipIndex, 4)
        XCTAssertEqual(loaded.currentLoopCount, 2)
        XCTAssertEqual(loaded.currentSpeed, 0.9, accuracy: 1e-6)
        XCTAssertEqual(loaded.clipPlayCounts, ["clipA": 3, "clipB": 1])
        XCTAssertTrue(loaded.foreverMode)
    }

    func testLoadMissingSessionReturnsNil() throws {
        XCTAssertNil(try svc.loadSession(packId: packId, trackId: trackId))
    }

    func testDeleteRemovesSession() throws {
        try svc.saveSession(makeSession())
        XCTAssertNotNil(try svc.loadSession(packId: packId, trackId: trackId))
        try svc.deleteSession(packId: packId, trackId: trackId)
        XCTAssertNil(try svc.loadSession(packId: packId, trackId: trackId))
    }

    func testDeleteMissingSessionDoesNotThrow() {
        XCTAssertNoThrow(try svc.deleteSession(packId: packId, trackId: trackId))
    }

    /// The synchronous write guarantees a load immediately after a save
    /// deterministically observes the latest data — the property the old
    /// fire-and-forget async could not promise.
    func testImmediateLoadAfterSaveSeesLatest() throws {
        for i in 0..<5 {
            var s = makeSession()
            s.currentClipIndex = i
            try svc.saveSession(s)
            let loaded = try XCTUnwrap(svc.loadSession(packId: packId, trackId: trackId))
            XCTAssertEqual(loaded.currentClipIndex, i)
        }
    }
}
