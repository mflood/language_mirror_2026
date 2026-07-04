//
//  StreakTracker.swift
//  LanguageMirror
//
//  Consecutive-practice-day streak. Session files are one-per-track and
//  overwritten on restart, so history can't be derived from them — instead
//  every completed loop records today's date here (idempotent set-add).
//
//  Streak semantics: if the user practiced today, the streak includes
//  today; otherwise it counts back from yesterday, so the number doesn't
//  read as "broken" before the day's practice has happened.
//

import Foundation

enum StreakTracker {

    private static let key = "streak.practiceDays"
    private static let maxStoredDays = 400

    private static var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar.current
        f.timeZone = TimeZone.current
        return f
    }

    /// Record that practice happened today. Cheap and idempotent.
    static func recordPracticeToday(defaults: UserDefaults = .standard, now: Date = Date()) {
        let today = dayFormatter.string(from: now)
        var days = defaults.stringArray(forKey: key) ?? []
        guard !days.contains(today) else { return }
        days.append(today)
        if days.count > maxStoredDays {
            days.removeFirst(days.count - maxStoredDays)
        }
        defaults.set(days, forKey: key)
    }

    /// Current consecutive-day streak ending today (or yesterday, if today
    /// hasn't been practiced yet). 0 = no active streak.
    static func currentStreak(defaults: UserDefaults = .standard, now: Date = Date()) -> Int {
        let days = Set(defaults.stringArray(forKey: key) ?? [])
        guard !days.isEmpty else { return 0 }

        let calendar = Calendar.current
        let formatter = dayFormatter
        var cursor = now

        // An active streak must include today or yesterday.
        if !days.contains(formatter.string(from: cursor)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(formatter.string(from: yesterday)) else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        while days.contains(formatter.string(from: cursor)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
