//
//  SettingsCoordinator.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//

import UIKit

@MainActor
final class SettingsCoordinator: Coordinator {
    let navigationController = UINavigationController()
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func start() -> UINavigationController {
        let vc = SettingsViewController(settings: container.settings)
        vc.title = "Settings"
        navigationController.viewControllers = [vc]
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }
}
