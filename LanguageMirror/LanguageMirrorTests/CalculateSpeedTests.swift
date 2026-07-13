//
//  CalculateSpeedTests.swift
//  LanguageMirrorTests
//
//  Regression tests for PracticeServiceJSON.calculateSpeed — the M-N-O speed
//  ramp that drives progression practice. Guards the N==1 divide-by-zero
//  (0/0 → NaN → AVPlayer silently stalls) that three code-review agents
//  independently flagged, plus the core progression math.
//

import XCTest
@testable import LanguageMirror

final class CalculateSpeedTests: XCTestCase {

    private let svc = PracticeServiceJSON()

    private func speed(progression: Bool = true,
                       simple: Float = 1.0,
                       loop: Int,
                       m: Int, n: Int, o: Int,
                       minS: Float = 0.6, maxS: Float = 1.0) -> Float {
        return svc.calculateSpeed(useProgressionMode: progression,
                                  simpleSpeed: simple,
                                  currentLoop: loop,
                                  progressionMinRepeats: m,
                                  progressionLinearRepeats: n,
                                  progressionMaxRepeats: o,
                                  minSpeed: minS, maxSpeed: maxS)
    }

    func testSimpleModeReturnsSimpleSpeed() {
        for loop in 0..<10 {
            XCTAssertEqual(speed(progression: false, simple: 0.8,
                                 loop: loop, m: 3, n: 5, o: 3), 0.8, accuracy: 1e-6)
        }
    }

    func testMinPhaseHoldsMinSpeed() {
        for loop in 0..<3 {
            XCTAssertEqual(speed(loop: loop, m: 3, n: 5, o: 3), 0.6, accuracy: 1e-6)
        }
    }

    func testMaxPhaseHoldsMaxSpeed() {
        // currentLoop >= M + N (== 8) holds at maxSpeed regardless of O.
        for loop in 8..<15 {
            XCTAssertEqual(speed(loop: loop, m: 3, n: 5, o: 3), 1.0, accuracy: 1e-6)
        }
    }

    func testRampInterpolatesEndpointsAndMidpoint() {
        // M=3, N=5: loop 3 → ratio 0 → minSpeed; loop 7 (M+N-1) → ratio 1 → maxSpeed.
        XCTAssertEqual(speed(loop: 3, m: 3, n: 5, o: 3), 0.6, accuracy: 1e-6)
        XCTAssertEqual(speed(loop: 7, m: 3, n: 5, o: 3), 1.0, accuracy: 1e-6)
        // loop 5 → ratio 0.5 → halfway between 0.6 and 1.0 = 0.8.
        XCTAssertEqual(speed(loop: 5, m: 3, n: 5, o: 3), 0.8, accuracy: 1e-6)
    }

    /// The Blocker: progressionLinearRepeats == 1 makes N-1 == 0. Before the
    /// guard this was 0/0 = NaN, which AVPlayer silently ignores so playback
    /// stalls with no audio. It must be a finite speed (maxSpeed) instead.
    func testSingleRampStepDoesNotProduceNaN() {
        // M=3, N=1 → the ramp region is exactly loop 3 (3 <= loop < M+N == 4).
        let s = speed(loop: 3, m: 3, n: 1, o: 3, minS: 0.6, maxS: 1.0)
        XCTAssertFalse(s.isNaN, "N==1 must not yield NaN")
        XCTAssertFalse(s.isInfinite, "N==1 must not yield infinity")
        XCTAssertEqual(s, 1.0, accuracy: 1e-6, "a single ramp step should jump to maxSpeed")
    }

    /// Exhaustive: no combination of settings the UI allows (N clamps to >= 1)
    /// should ever produce a non-finite or out-of-bounds rate.
    func testNeverProducesNonFiniteOrOutOfBoundsSpeed() {
        let minS: Float = 0.5, maxS: Float = 1.5
        for m in 0...5 {
            for n in 1...6 {
                for o in 0...5 {
                    for loop in 0...25 {
                        let s = speed(loop: loop, m: m, n: n, o: o, minS: minS, maxS: maxS)
                        XCTAssertTrue(s.isFinite,
                                      "non-finite at M=\(m) N=\(n) O=\(o) loop=\(loop): \(s)")
                        XCTAssertGreaterThanOrEqual(s, minS - 1e-6)
                        XCTAssertLessThanOrEqual(s, maxS + 1e-6)
                    }
                }
            }
        }
    }

    /// Across advancing loops the ramp never decreases (slow → fast, never back).
    func testRampIsMonotonicNonDecreasing() {
        var prev: Float = -1
        for loop in 0...15 {
            let s = speed(loop: loop, m: 3, n: 6, o: 3, minS: 0.6, maxS: 1.2)
            XCTAssertGreaterThanOrEqual(s, prev, "speed decreased at loop \(loop)")
            prev = s
        }
    }

    /// Negative loop indices are defended against (guard returns minSpeed).
    func testNegativeLoopReturnsMinSpeed() {
        XCTAssertEqual(speed(loop: -1, m: 3, n: 5, o: 3), 0.6, accuracy: 1e-6)
    }
}
