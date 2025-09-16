//
//  SettingsService.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//

// path: Services/SettingsService.swift
import Foundation

protocol SettingsService: AnyObject {
    var globalRepeats: Int { get set }                 // >= 1
    var gapSeconds: TimeInterval { get set }           // between repeats of same segment
    var interSegmentGapSeconds: TimeInterval { get set } // between different segments
    var prerollMs: Int { get set }                     // 0..300 typical
    var duckOthers: Bool { get set }                     // duck other audio when playing
    // With duck ON, other audio dips under yours; with duck OFF, other audio keeps normal volume (but still mixed).
}

