//
//  ImportCoordinator.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

@MainActor
final class ImportCoordinator: Coordinator {
    let navigationController = UINavigationController()
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func start() -> UINavigationController {
        let vc = ImportViewController(importService: container.importService)
        vc.title = "Import"
        navigationController.viewControllers = [vc]
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }
    
    deinit {
        
        
        print("ImportCoordinator deinit") }
}
