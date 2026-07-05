//
//  AppDelegate.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//

import UIKit
import UserNotifications
import TelemetryDeck

extension Notification.Name {
    /// Posted when a daily-news notification is tapped; userInfo carries the
    /// bundle URL to open under `url`.
    static let openNewsBundle = Notification.Name("openNewsBundle")
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let config = TelemetryDeck.Config(appID: "465CBE0F-A4B8-4F59-BEAC-8FF8D777FC0D")
        TelemetryDeck.initialize(config: config)

        UIApplication.shared.beginReceivingRemoteControlEvents()

        // Receive notification taps (local daily reminder + future remote push).
        UNUserNotificationCenter.current().delegate = self

        // Keep the reminder schedule current if the user has it on.
        NewsNotificationService.refreshSchedule()
        return true
    }

    // MARK: - Remote push registration (scaffolding — see NEWS_PUSH_PIPELINE_SPEC.md)

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NewsNotificationService.storeDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("⚠️ [Push] Failed to register for remote notifications: \(error)")
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Show daily-news notifications even while the app is foregrounded.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    /// A notification was tapped. If it's the daily-news nudge, resolve the
    /// day's bundle URL and hand it to the coordinator (via NotificationCenter,
    /// which the AppCoordinator observes) to import + start practice.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if userInfo[NewsNotificationService.userInfoTypeKey] as? String == NewsNotificationService.userInfoTypeValue,
           let url = NewsNotificationService.bundleURL(fromNotificationUserInfo: userInfo) {
            // Stash for cold launch (observer not up yet) AND post for warm.
            NewsNotificationService.pendingBundleURL = url
            NotificationCenter.default.post(name: .openNewsBundle, object: nil, userInfo: ["url": url])
        }
        completionHandler()
    }
}

