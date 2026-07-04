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

        // 1. First launch — whatever greets a brand-new user
        Thread.sleep(forTimeInterval: 2)
        shot("01-first-launch")
        Thread.sleep(forTimeInterval: 5)   // give embedded starter import time
        shot("02-first-launch-settled")

        // 2. The four tabs as a new user sees them
        let tabs = app.tabBars.firstMatch
        for (name, label) in [("03-tab-import", "Import"),
                              ("04-tab-practice", "Practice"),
                              ("05-tab-settings", "Settings"),
                              ("06-tab-library", "Library")] {
            let b = tabs.buttons[label]
            if b.waitForExistence(timeout: 5) { b.tap() }
            Thread.sleep(forTimeInterval: 1)
            shot(name)
        }

        // 3. Obtaining content: what the Install Bundle flow looks like
        tabs.buttons["Import"].tap()
        Thread.sleep(forTimeInterval: 1)
        let bundleRow = app.staticTexts["Install Bundle"]
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
}
