//
//  ImportCoordinator.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

final class ImportCoordinator: Coordinator {
    let navigationController = UINavigationController()
    private let container: AppContainer

    init(container: AppContainer) { self.container = container }

    func start() -> UINavigationController {
        let vc = ImportViewController()
        vc.title = "Import"
        navigationController.viewControllers = [vc]
        return navigationController
    }
    
    deinit {
        
        
        print("ImportCoordinator deinit") }
}
