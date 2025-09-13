//
//  SettingsCoordinator.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

final class SettingsCoordinator: Coordinator {
    let navigationController = UINavigationController()
    private let container: AppContainer

    init(container: AppContainer) { self.container = container }

    func start() -> UINavigationController {
        let vc = SettingsViewController()
        vc.title = "Settings"
        navigationController.viewControllers = [vc]
        return navigationController
    }
}
