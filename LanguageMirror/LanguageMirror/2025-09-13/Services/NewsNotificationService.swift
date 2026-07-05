//
//  NewsNotificationService.swift
//  LanguageMirror
//
//  Daily-news reminder. Each morning, nudge the learner to practice the
//  day's Korean news pack — feeding the practice streak (see StreakTracker).
//
//  Ships as a LOCAL notification (no backend, no push entitlement needed):
//  the app schedules a repeating reminder and, on tap, constructs the day's
//  news-pack URL from the known CloudFront pattern and imports it. A remote
//  (APNs) upgrade — where the pipeline sends the push only after publishing,
//  with the real title — is specced in NEWS_PUSH_PIPELINE_SPEC.md and
//  scaffolded here (device-token capture) but not force-registered.
//

import Foundation
import UserNotifications

enum NewsNotificationService {

    // MARK: - Config

    private static let cloudFrontBase = "https://d1ni0tk3ua6bwo.cloudfront.net"
    private static let requestIdentifier = "dailyNewsReminder"

    /// userInfo marker so the tap handler knows this is the daily-news nudge.
    static let userInfoTypeKey = "type"
    static let userInfoTypeValue = "dailyNews"
    /// Optional explicit bundle URL (used by remote pushes); local reminders
    /// derive the URL at tap time instead.
    static let userInfoBundleURLKey = "bundleUrl"

    // MARK: - Preferences (UserDefaults-backed)

    private enum Keys {
        static let enabled = "news.reminder.enabled"
        static let hour = "news.reminder.hour"
        static let minute = "news.reminder.minute"
        static let deviceToken = "news.push.deviceToken"
    }

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.enabled) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.enabled) }
    }

    /// Reminder time-of-day, default 08:00 local.
    static var reminderHour: Int {
        get { UserDefaults.standard.object(forKey: Keys.hour) as? Int ?? 8 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hour) }
    }
    static var reminderMinute: Int {
        get { UserDefaults.standard.object(forKey: Keys.minute) as? Int ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.minute) }
    }

    // MARK: - Authorization

    /// Ask for notification permission. Completion reports whether granted.
    static func requestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    /// Enable the daily reminder: request permission, and on grant persist the
    /// preference and schedule it. No-op harm if permission is denied.
    static func enableReminder(completion: ((Bool) -> Void)? = nil) {
        requestAuthorization { granted in
            isEnabled = granted
            if granted { scheduleDailyReminder() }
            completion?(granted)
        }
    }

    static func disableReminder() {
        isEnabled = false
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
    }

    // MARK: - Scheduling

    /// (Re)schedule the repeating daily reminder at the configured time.
    static func scheduleDailyReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])

        let content = UNMutableNotificationContent()
        content.title = L10n("news_reminder.title")
        content.body = L10n("news_reminder.body")
        content.sound = .default
        content.userInfo = [userInfoTypeKey: userInfoTypeValue]

        var date = DateComponents()
        date.hour = reminderHour
        date.minute = reminderMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)

        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
        center.add(request)
    }

    /// Keep the schedule in sync after a settings change or app foreground.
    static func refreshSchedule() {
        if isEnabled {
            scheduleDailyReminder()
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        }
    }

    // MARK: - Day's bundle URL

    /// Stable alias the pipeline copies the freshest pack to after each publish
    /// (see NEWS_PUSH_PIPELINE_SPEC.md). Preferred over a client-constructed
    /// dated URL: it always resolves even if a run slips or the device clock
    /// disagrees, and its inner id/audio URLs stay dated so imports dedup.
    static let latestNewsBundleURL = URL(string: "\(cloudFrontBase)/lmaudio/news_latest/bundle.json")!

    /// The news pack URL for a given day, following the pipeline's publish
    /// pattern lmaudio/news_YYYY_MM_DD/bundle.json. Retained for callers that
    /// need a specific day; the daily reminder uses `latestNewsBundleURL`.
    static func newsBundleURL(for date: Date = Date()) -> URL? {
        var calendar = Calendar(identifier: .gregorian)
        // The daily pipeline dates packs in US/Eastern; match it so the
        // constructed URL lines up with what was published.
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return nil }
        let id = String(format: "news_%04d_%02d_%02d", y, m, d)
        return URL(string: "\(cloudFrontBase)/lmaudio/\(id)/bundle.json")
    }

    /// Resolve the bundle URL a tapped notification should open. Remote pushes
    /// carry an explicit dated URL; local reminders open the stable alias.
    static func bundleURL(fromNotificationUserInfo userInfo: [AnyHashable: Any]) -> URL? {
        if let explicit = userInfo[userInfoBundleURLKey] as? String, let url = URL(string: explicit) {
            return url
        }
        return latestNewsBundleURL
    }

    /// A notification tapped on a COLD launch is delivered before the
    /// AppCoordinator has registered its observer, so the posted event is
    /// missed. The tap handler also stashes the URL here; the coordinator
    /// drains it once it's ready.
    static var pendingBundleURL: URL?

    // MARK: - Remote push scaffolding (see NEWS_PUSH_PIPELINE_SPEC.md)

    /// Record the APNs device token. Not wired to a backend yet — when the
    /// push server exists, POST this token to it here.
    static func storeDeviceToken(_ token: Data) {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: Keys.deviceToken)
        print("📮 [Push] APNs device token: \(hex)")
        // TODO: POST hex to the push backend once it exists.
    }
}
