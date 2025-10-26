//
//  SettingsServiceUserDefaults.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/16/25.
//
import Foundation

final class SettingsServiceUserDefaults: SettingsService {
    private let d = UserDefaults.standard

    private enum Key: String {
        case repeats = "settings.globalRepeats"
        case gap = "settings.gapSeconds"
        case interGap = "settings.interSegmentGapSeconds"
        case preroll = "settings.prerollMs"
        case duckOthers = "settings.duckOthers"
        case useProgressionMode = "settings.useProgressionMode"
        case progressionMinRepeats = "settings.progressionMinRepeats"
        case progressionLinearRepeats = "settings.progressionLinearRepeats"
        case progressionMaxRepeats = "settings.progressionMaxRepeats"
        case minSpeed = "settings.minSpeed"
        case maxSpeed = "settings.maxSpeed"
    }

    // Defaults
    private let defaultRepeats = 3
    private let defaultGap: TimeInterval = 0.5
    private let defaultInterGap: TimeInterval = 0.5
    private let defaultPrerollMs = 0
    private let defaultDuck = false
    private let defaultUseProgressionMode = false
    private let defaultProgressionMinRepeats = 5
    private let defaultProgressionLinearRepeats = 10
    private let defaultProgressionMaxRepeats = 5
    private let defaultMinSpeed: Float = 0.6
    private let defaultMaxSpeed: Float = 1.0

    var globalRepeats: Int {
        get { max(1, d.integer(forKey: Key.repeats.rawValue) == 0 ? defaultRepeats : d.integer(forKey: Key.repeats.rawValue)) }
        set { d.set(max(1, min(newValue, 100)), forKey: Key.repeats.rawValue) }
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
    
    var duckOthers: Bool {
        get { d.object(forKey: Key.duckOthers.rawValue) as? Bool ?? defaultDuck }
        set { d.set(newValue, forKey: Key.duckOthers.rawValue) }
    }
    
    var minSpeed: Float {
        get {
            let v = d.object(forKey: Key.minSpeed.rawValue) as? Float
            return v ?? defaultMinSpeed
        }
        set { d.set(max(0.3, min(newValue, 1.0)), forKey: Key.minSpeed.rawValue) }
    }
    
    var maxSpeed: Float {
        get {
            let v = d.object(forKey: Key.maxSpeed.rawValue) as? Float
            return v ?? defaultMaxSpeed
        }
        set { d.set(max(0.5, min(newValue, 3.0)), forKey: Key.maxSpeed.rawValue) }
    }
    
    var useProgressionMode: Bool {
        get { d.object(forKey: Key.useProgressionMode.rawValue) as? Bool ?? defaultUseProgressionMode }
        set { d.set(newValue, forKey: Key.useProgressionMode.rawValue) }
    }
    
    var progressionMinRepeats: Int {
        get {
            let v = d.object(forKey: Key.progressionMinRepeats.rawValue) as? Int
            return v ?? defaultProgressionMinRepeats
        }
        set { d.set(max(1, min(newValue, 100)), forKey: Key.progressionMinRepeats.rawValue) }
    }
    
    var progressionLinearRepeats: Int {
        get {
            let v = d.object(forKey: Key.progressionLinearRepeats.rawValue) as? Int
            return v ?? defaultProgressionLinearRepeats
        }
        set { d.set(max(1, min(newValue, 100)), forKey: Key.progressionLinearRepeats.rawValue) }
    }
    
    var progressionMaxRepeats: Int {
        get {
            let v = d.object(forKey: Key.progressionMaxRepeats.rawValue) as? Int
            return v ?? defaultProgressionMaxRepeats
        }
        set { d.set(max(1, min(newValue, 100)), forKey: Key.progressionMaxRepeats.rawValue) }
    }
}
