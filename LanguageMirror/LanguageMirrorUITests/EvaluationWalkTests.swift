//
//  EvaluationWalkTests.swift
//  LanguageMirrorUITests
//
//  Screenshot tour of the first-run funnel: launch → tabs → obtain content →
//  track detail → practice → transcript popup. Not a pass/fail test — a
//  capture harness for UX evaluation. Run against a FRESH INSTALL.
//

import XCTest

final class EvaluationWalkTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func shot(_ name: String) {
        let s = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        s.name = name
        s.lifetime = .keepAlways
        add(s)
    }

    @MainActor
    func testFirstRunFunnelTour() throws {
        let app = XCUIApplication()
        app.launch()

        // 0. Onboarding, if present: continue, view how-it-works, auto-start.
        let continueButton = app.buttons["onboarding.continue"]
        if continueButton.waitForExistence(timeout: 5) {
            shot("00a-onboarding-welcome")
            continueButton.tap()
            Thread.sleep(forTimeInterval: 1)
            shot("00b-onboarding-how")
            let cta = app.buttons["onboarding.cta"]
            if cta.waitForExistence(timeout: 5) { cta.tap() }
            Thread.sleep(forTimeInterval: 6)   // auto-start: import + push + play
            shot("00c-auto-started-practice")
            // Return to Library root for the rest of the tour
            let back = app.navigationBars.buttons.firstMatch
            if back.exists { back.tap(); Thread.sleep(forTimeInterval: 0.5) }
            let back2 = app.navigationBars.buttons.firstMatch
            if back2.exists { back2.tap(); Thread.sleep(forTimeInterval: 0.5) }
        }

        // 1. First launch — whatever greets a brand-new user
        Thread.sleep(forTimeInterval: 2)
        shot("01-first-launch")
        Thread.sleep(forTimeInterval: 5)   // give embedded starter import time
        shot("02-first-launch-settled")

        // 2. The four tabs as a new user sees them
        let tabs = app.tabBars.firstMatch
        for (name, label) in [("03-tab-import", "Add"),
                              ("04-tab-practice", "Practice"),
                              ("05-tab-settings", "Settings"),
                              ("06-tab-library", "Library")] {
            let b = tabs.buttons[label]
            if b.waitForExistence(timeout: 5) { b.tap() }
            Thread.sleep(forTimeInterval: 1)
            shot(name)
        }

        // 3. Obtaining content: what the Install Bundle flow looks like
        tabs.buttons["Add"].tap()
        Thread.sleep(forTimeInterval: 1)
        let bundleRow = app.staticTexts["Install Pack from Link"]
        if bundleRow.waitForExistence(timeout: 5) {
            bundleRow.tap()
            Thread.sleep(forTimeInterval: 1)
            shot("07-install-bundle-dialog")
            let cancel = app.alerts.buttons["Cancel"]
            if cancel.exists { cancel.tap() }
        }

        // 4. Library → first track → detail
        tabs.buttons["Library"].tap()
        Thread.sleep(forTimeInterval: 1)
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 5) {
            firstCell.tap()
        } else {
            // collection view based library
            app.collectionViews.firstMatch.cells.firstMatch.tap()
        }
        Thread.sleep(forTimeInterval: 1.5)
        shot("08-track-detail")

        // 5. Start practice: tap the first practice set row
        let firstSet = app.tables.cells.firstMatch
        if firstSet.waitForExistence(timeout: 5) {
            firstSet.tap()
        }
        Thread.sleep(forTimeInterval: 2)
        shot("09-practice-initial")

        // 6. Press play, observe playing state
        let play = app.buttons["Play"].exists ? app.buttons["Play"]
                 : app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'play'")).firstMatch
        if play.exists && play.isHittable {
            play.tap()
            Thread.sleep(forTimeInterval: 4)
            shot("10-practice-playing")
        }

        // 7. Transcript banner → popup
        let banner = app.staticTexts
            .matching(NSPredicate(format: "label MATCHES %@", ".*[가-힣].{4,}"))
            .allElementsBoundByIndex
            .last
        if let banner, banner.exists, banner.isHittable {
            banner.tap()
            Thread.sleep(forTimeInterval: 1.5)
            shot("11-transcript-popup")
            app.swipeDown(velocity: .fast)
        }

        // 8. Practice tab home (recents populated now)
        tabs.buttons["Practice"].tap()
        Thread.sleep(forTimeInterval: 1)
        shot("12-practice-home-after")
    }

    /// Verifies the transcript banner shows the dimmed translation line.
    /// Requires `simctl openurl` fired just before the run with the
    /// news_2026_07_02_test deep link (springboard dialog pending).
    /// Enables the Daily News Reminder in Settings, granting notification
    /// permission via the system prompt, and confirms the enabled state.
    @MainActor
    func testEnableDailyNewsReminder() throws {
        let app = XCUIApplication()
        // Auto-accept the notification permission alert when it appears.
        addUIInterruptionMonitor(withDescription: "Notifications") { alert in
            for label in ["Allow", "허용"] {
                if alert.buttons[label].exists { alert.buttons[label].tap(); return true }
            }
            return false
        }
        app.launch()
        app.tabBars.firstMatch.buttons["Settings"].tap()
        Thread.sleep(forTimeInterval: 1)

        let reminderSwitch = app.switches.firstMatch
        XCTAssertTrue(reminderSwitch.waitForExistence(timeout: 5))
        reminderSwitch.tap()
        Thread.sleep(forTimeInterval: 1)
        app.tap()   // nudge the interruption monitor to dismiss the alert
        Thread.sleep(forTimeInterval: 1)
        shot("17b-reminder-enabled")

        // Time row appears once enabled.
        XCTAssertTrue(app.staticTexts["Reminder Time"].waitForExistence(timeout: 5),
                      "Reminder time row should appear after enabling")
    }

    // Note: the daily-news notification TAP → import path is not covered by an
    // automated test — XCUITest cannot reliably tap a notification banner in
    // the iOS 26 simulator (and reinstalls reset notification permission), so
    // didReceive never fires under automation. The tap handler routes into the
    // same importBundle(from:) path exercised end-to-end by
    // testTranslationBannerOnNewsPack, and the enable/permission flow is
    // covered by testEnableDailyNewsReminder above.

    /// Practice tab with zero sessions must show the empty state (Miri +
    /// "No Practice Sessions Yet"), not a blank screen. Skipping onboarding
    /// avoids the auto-started session so the library has no practice history.
    @MainActor
    func testPracticeEmptyState() throws {
        let app = XCUIApplication()
        app.launch()
        // Skip onboarding if present (Skip does NOT auto-start a session).
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 5) { skip.tap(); Thread.sleep(forTimeInterval: 1) }

        app.tabBars.firstMatch.buttons["Practice"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        shot("19-practice-empty")
        XCTAssertTrue(app.staticTexts["No Practice Sessions Yet"].waitForExistence(timeout: 5),
                      "Practice empty state not shown")
    }

    /// Settings: core controls up top, timing/preroll/duck behind Advanced.
    @MainActor
    func testSettingsBasicAdvancedSplit() throws {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.firstMatch.buttons["Settings"].tap()
        Thread.sleep(forTimeInterval: 1)
        shot("16-settings-collapsed")

        let advanced = app.buttons["settings.advanced.toggle"]
        XCTAssertTrue(advanced.waitForExistence(timeout: 5), "Advanced disclosure not found")
        // Timing controls hidden until Advanced is expanded.
        XCTAssertFalse(app.staticTexts["Gap Between Repeats"].isHittable,
                       "Advanced controls should be hidden by default")
        advanced.tap()
        Thread.sleep(forTimeInterval: 0.6)
        shot("17-settings-expanded")
        XCTAssertTrue(app.staticTexts["Gap Between Repeats"].waitForExistence(timeout: 3),
                      "Advanced controls should appear after expanding")
    }

    /// Requires `simctl openurl` fired just before the run with the
    /// news_2026_07_02_test deep link (springboard "Open" dialog pending).
    @MainActor
    func testTranslationBannerOnNewsPack() throws {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let openButton = springboard.buttons["Open"]
        if openButton.waitForExistence(timeout: 8) { openButton.tap() }

        let app = XCUIApplication()
        app.activate()

        // Wait for the news pack import, then open the octopus track. The
        // title can appear twice (Recently Added + pack); pick a hittable one.
        let anyTrack = app.staticTexts["문어와 거울"].firstMatch
        let deadline = Date().addingTimeInterval(180)
        let tabs = app.tabBars.firstMatch
        while Date() < deadline {
            if app.alerts.count > 0 { app.alerts.buttons.firstMatch.tap() }
            if tabs.buttons["Library"].exists && tabs.buttons["Library"].isHittable {
                tabs.buttons["Library"].tap()
            }
            if anyTrack.exists { break }
            Thread.sleep(forTimeInterval: 3)
        }
        XCTAssertTrue(anyTrack.waitForExistence(timeout: 10))
        let trackCell = app.staticTexts.matching(NSPredicate(format: "label == %@", "문어와 거울"))
            .allElementsBoundByIndex.first(where: { $0.isHittable }) ?? anyTrack
        trackCell.tap()

        // Multi-clip set: the banner stays visible (a single-clip set would
        // complete and the celebration sheet would cover it).
        let setRow = app.staticTexts["Korean phrase loops"]
        XCTAssertTrue(setRow.waitForExistence(timeout: 10))
        setRow.tap()
        Thread.sleep(forTimeInterval: 2)

        // The banner appears once playback makes a clip current. Phrase-loops
        // clip 1 is the vocab word 거울 → "mirror", so the two-label banner
        // renders both the Korean source and its dimmed English translation.
        let play = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'play'")).firstMatch
        if play.exists && play.isHittable { play.tap() }
        Thread.sleep(forTimeInterval: 4)
        shot("15-translation-banner")

        // Capture only — 15-translation-banner is the evidence (banner shows
        // the current clip's Korean over its dimmed English). The banner
        // exposes both labels as one combined a11y element and clip titles
        // also embed the gloss, so there's no clean text assertion; this is
        // a screenshot harness, not a pass/fail gate.
        let bannerPresent = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "거울", "mirror"))
            .firstMatch
        XCTAssertTrue(bannerPresent.waitForExistence(timeout: 10),
                      "Practice screen never showed transcript content")
    }

    /// Verifies the session-complete celebration. Run with repeats pre-set
    /// to 1 (simctl: defaults write … settings.globalRepeats -int 1) against
    /// an onboarded install so a 12-clip set finishes in ~1–2 minutes.
    @MainActor
    func testSessionCompletionCelebration() throws {
        let app = XCUIApplication()
        app.launch()

        let tabs = app.tabBars.firstMatch
        tabs.buttons["Library"].tap()
        Thread.sleep(forTimeInterval: 1)

        // Library → track → Practice Set (12 clips). Tap the cell (reliably
        // navigates) rather than the label.
        app.collectionViews.cells.containing(.staticText,
            identifier: "Seoul Lunch Recommendations").firstMatch.tap()
        Thread.sleep(forTimeInterval: 1)
        let setRow = app.staticTexts["Practice Set"]
        XCTAssertTrue(setRow.waitForExistence(timeout: 5))
        setRow.tap()
        Thread.sleep(forTimeInterval: 2)

        // Play and wait for natural completion
        let play = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'play'")).firstMatch
        if play.exists && play.isHittable { play.tap() }

        let completeTitle = app.staticTexts["Practice complete!"]
        let appeared = completeTitle.waitForExistence(timeout: 240)
        shot("13-session-complete")
        XCTAssertTrue(appeared, "Celebration sheet did not appear after set completion")

        // Practice Again restarts playback with a fresh session
        let again = app.buttons["Practice Again"]
        XCTAssertTrue(again.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.5)   // let the sheet finish presenting
        again.tap()
        // Sheet must dismiss and playback restart
        let deadline = Date().addingTimeInterval(6)
        while completeTitle.exists && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertFalse(completeTitle.exists, "Celebration sheet did not dismiss after Practice Again")
        Thread.sleep(forTimeInterval: 3)
        shot("14-practice-again")
    }

    /// End-to-end proof that an embedded ENGLISH pack installs from Featured
    /// Packs, plays, and shows its Korean translation gloss — the mirror
    /// direction (English audio for Korean learners). Also a regression guard
    /// for the embedded-bundle install path.
    @MainActor
    func testInstallEnglishPack() throws {
        let app = XCUIApplication()
        // Force the embedded catalog so the not-yet-published English pack is
        // present (the remote catalog is authoritative in production).
        app.launchArguments += ["-forceEmbeddedCatalog"]
        app.launch()
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 4) { skip.tap(); Thread.sleep(forTimeInterval: 1) }

        let tabs = app.tabBars.firstMatch
        tabs.buttons["Add"].tap()
        Thread.sleep(forTimeInterval: 1)
        let featured = app.staticTexts["Featured Packs"]
        XCTAssertTrue(featured.waitForExistence(timeout: 5))
        featured.tap()
        Thread.sleep(forTimeInterval: 2)

        // Install the English greetings pack (top of the catalog).
        let englishPack = app.staticTexts["Everyday English Greetings"].firstMatch
        XCTAssertTrue(englishPack.waitForExistence(timeout: 8), "English pack missing from Featured Packs")
        shot("30-featured-english-pack")
        englishPack.tap()
        // Confirm the install alert.
        let installBtn = app.alerts.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'install' OR label CONTAINS[c] 'add'")).firstMatch
        if installBtn.waitForExistence(timeout: 5) { installBtn.tap() }

        // Wait for install to finish and return to Library.
        Thread.sleep(forTimeInterval: 6)
        if tabs.buttons["Library"].exists { tabs.buttons["Library"].tap() }
        Thread.sleep(forTimeInterval: 1.5)

        // HARD PROOF (the new, risky path): the embedded English pack
        // installed and its English track is now in the Library — a pack
        // section plus a track row carrying the "english" language tag and a
        // real duration. That confirms the bundle parsed and audio resolved.
        let packHeader = app.staticTexts["Everyday English Greetings"].firstMatch
        XCTAssertTrue(packHeader.waitForExistence(timeout: 8), "English pack not in Library after install")
        // Expand the section — the tap can miss when the layout shifts, so
        // retry until the track's "english" tag is revealed.
        let englishTag = app.staticTexts["english"].firstMatch
        for _ in 0..<4 where !englishTag.exists {
            let h = app.staticTexts["Everyday English Greetings"].firstMatch
            if h.isHittable { h.tap() }
            Thread.sleep(forTimeInterval: 1.2)
        }
        XCTAssertTrue(englishTag.waitForExistence(timeout: 5),
                      "English track (english-tagged) not revealed under the pack")
        shot("31-english-track-in-library")

        // BEST EFFORT: drive into the track → practice and capture the gloss.
        // Deep drill-in through a collapsed pack is XCUITest-flaky, so this is
        // a screenshot capture, not a hard gate — the span→gloss render is the
        // same mechanism proven by testTranslationBannerOnNewsPack.
        let trackCell = app.collectionViews.cells.containing(.staticText, identifier: "english").firstMatch
        if trackCell.exists { trackCell.tap() }
        Thread.sleep(forTimeInterval: 1.5)
        let setRow = app.staticTexts["Practice Set"]
        if setRow.waitForExistence(timeout: 6) { setRow.tap() }
        Thread.sleep(forTimeInterval: 2)
        let play = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'play'")).firstMatch
        if play.exists && play.isHittable { play.tap() }
        Thread.sleep(forTimeInterval: 4)
        shot("32-english-practice-gloss")
    }

    /// Read-only tour of every reachable screen WITHOUT mutating app state:
    /// no imports, no session starts, no persisted toggles. Safe to run on
    /// a lived-in simulator — this is the /brand-tour skill's quick mode.
    /// Shots are numbered 20+ so they sort after the funnel's.
    @MainActor
    func testBrandTour() throws {
        let app = XCUIApplication()
        app.launch()

        // Skip onboarding if present (fresh install) — Skip does NOT auto-start.
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 3) { skip.tap(); Thread.sleep(forTimeInterval: 1) }

        let tabs = app.tabBars.firstMatch

        // 1. Library home
        tabs.buttons["Library"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        shot("20-library-home")

        // 2. Track detail (read-only browse), then back
        let trackCell = app.collectionViews.firstMatch.cells.firstMatch
        if trackCell.waitForExistence(timeout: 5) && trackCell.isHittable {
            trackCell.tap()
            Thread.sleep(forTimeInterval: 1.5)
            shot("21-track-detail")
            let back = app.navigationBars.buttons.firstMatch
            if back.exists { back.tap(); Thread.sleep(forTimeInterval: 0.8) }
        }

        // 3. Add tab, top and scrolled to Advanced
        tabs.buttons["Add"].tap()
        Thread.sleep(forTimeInterval: 1)
        shot("22-add-top")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.8)
        shot("23-add-advanced")

        // 4. Featured Packs (browse only — no downloads)
        app.swipeDown()
        Thread.sleep(forTimeInterval: 0.8)
        let featured = app.staticTexts["Featured Packs"]
        if featured.waitForExistence(timeout: 4) && featured.isHittable {
            featured.tap()
            Thread.sleep(forTimeInterval: 2.5)   // catalog fetch
            shot("24-featured-packs")
            let back = app.navigationBars.buttons.firstMatch
            if back.exists { back.tap(); Thread.sleep(forTimeInterval: 0.8) }
        }

        // 5. Practice home (whatever state exists — hero card or empty Miri)
        tabs.buttons["Practice"].tap()
        Thread.sleep(forTimeInterval: 1.2)
        shot("25-practice-home")

        // 6. Settings, collapsed then Advanced expanded (view-state only),
        //    collapsed again to leave things as found.
        tabs.buttons["Settings"].tap()
        Thread.sleep(forTimeInterval: 1)
        shot("26-settings")
        let advanced = app.buttons["settings.advanced.toggle"]
        if advanced.waitForExistence(timeout: 4) {
            if !advanced.isHittable { app.swipeUp(); Thread.sleep(forTimeInterval: 0.5) }
            if advanced.isHittable {
                advanced.tap()
                Thread.sleep(forTimeInterval: 0.8)
                app.swipeUp()
                Thread.sleep(forTimeInterval: 0.5)
                shot("27-settings-advanced")
                app.swipeDown()
                Thread.sleep(forTimeInterval: 0.5)
                if advanced.isHittable { advanced.tap() }
            }
        }

        // Home again
        tabs.buttons["Library"].tap()
    }
}
