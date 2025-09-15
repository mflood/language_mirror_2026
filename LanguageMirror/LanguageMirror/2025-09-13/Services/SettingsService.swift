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
}

final class SettingsServiceUserDefaults: SettingsService {
    private let d = UserDefaults.standard

    private enum Key: String {
        case repeats = "settings.globalRepeats"
        case gap = "settings.gapSeconds"
        case interGap = "settings.interSegmentGapSeconds"
        case preroll = "settings.prerollMs"
    }

    // Defaults
    private let defaultRepeats = 3
    private let defaultGap: TimeInterval = 0.5
    private let defaultInterGap: TimeInterval = 0.5
    private let defaultPrerollMs = 0

    var globalRepeats: Int {
        get { max(1, d.integer(forKey: Key.repeats.rawValue) == 0 ? defaultRepeats : d.integer(forKey: Key.repeats.rawValue)) }
        set { d.set(max(1, min(newValue, 20)), forKey: Key.repeats.rawValue) }
    }

    var gapSeconds: TimeInterval {
        get {
            let v = d.object(forKey: Key.gap.rawValue) as? Double
            return v ?? defaultGap
        }
        set { d.set(max(0.0, min(newValue, 5.0)), forKey: Key.gap.rawValue) }
    }

    var interSegmentGapSeconds: TimeInterval {
        get {
            let v = d.object(forKey: Key.interGap.rawValue) as? Double
            return v ?? defaultInterGap
        }
        set { d.set(max(0.0, min(newValue, 5.0)), forKey: Key.interGap.rawValue) }
    }

    var prerollMs: Int {
        get {
            let v = d.object(forKey: Key.preroll.rawValue) as? Int
            return v ?? defaultPrerollMs
        }
        set { d.set(max(0, min(newValue, 1000)), forKey: Key.preroll.rawValue) }
    }
}
