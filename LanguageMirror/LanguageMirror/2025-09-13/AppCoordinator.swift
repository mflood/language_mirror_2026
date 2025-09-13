//
//  AppCoordinator.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

final class AppCoordinator {
    private let window: UIWindow
    private let container: AppContainer
    private let tabBarController = UITabBarController()

    init(window: UIWindow, container: AppContainer) {
        self.window = window
        self.container = container
    }

    func start() {
        // Child coordinators
        let libraryNav  = LibraryCoordinator(container: container).start()
        libraryNav.tabBarItem  = UITabBarItem(title: "Library",
                                              image: UIImage(systemName: "books.vertical"),
                                              tag: 0)

        let importNav   = ImportCoordinator(container: container).start()
        importNav.tabBarItem   = UITabBarItem(title: "Import",
                                              image: UIImage(systemName: "square.and.arrow.down"),
                                              tag: 1)

        let practiceNav = PracticeCoordinator(container: container).start()
        practiceNav.tabBarItem = UITabBarItem(title: "Practice",
                                              image: UIImage(systemName: "repeat"),
                                              tag: 2)

        let settingsNav = SettingsCoordinator(container: container).start()
        settingsNav.tabBarItem = UITabBarItem(title: "Settings",
                                              image: UIImage(systemName: "gearshape"),
                                              tag: 3)

        tabBarController.viewControllers = [libraryNav, importNav, practiceNav, settingsNav]
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
    }
}
