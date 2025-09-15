//
//  PracticeCoordinator.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

final class PracticeCoordinator: Coordinator {
    let navigationController = UINavigationController()
    private let container: AppContainer

    init(container: AppContainer) { self.container = container }

    func start() -> UINavigationController {
        let vc = PracticeViewController(
            settings: container.settings,
            libraryService: container.libraryService,
            segmentService: container.segmentService,
            audioPlayer: container.audioPlayer
        )
        vc.title = "Practice"
        navigationController.viewControllers = [vc]
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }
}

