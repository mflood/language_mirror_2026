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
    
    // Practice mode settings
    var useProgressionMode: Bool { get set }           // toggle between simple and progression modes
    var progressionMinRepeats: Int { get set }         // M repeats at minimum speed (1-100)
    var progressionLinearRepeats: Int { get set }      // N repeats during linear progression (1-100)
    var progressionMaxRepeats: Int { get set }         // O repeats at maximum speed (1-100)
    
    // Speed settings
    var minSpeed: Float { get set }                    // 0.3..1.0
    var maxSpeed: Float { get set }                    // 0.5..3.0
}

