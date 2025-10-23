//
//  PracticeCoordinator.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

@MainActor
final class PracticeCoordinator: Coordinator {
    let navigationController = UINavigationController()
    private let container: AppContainer
    private weak var appCoordinator: AppCoordinator?

    init(container: AppContainer, appCoordinator: AppCoordinator) {
        self.container = container
        self.appCoordinator = appCoordinator
    }

    func start() -> UINavigationController {
        let vc = PracticeHomeViewController(
            libraryService: container.libraryService,
            practiceService: container.practiceService
        )
        vc.title = "Practice"
        vc.delegate = self
        navigationController.viewControllers = [vc]
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }
    
    func loadPracticeSet(track: Track, practiceSet: PracticeSet) {
        // This method is no longer needed since we're using PracticeHomeViewController
        // The navigation is handled by AppCoordinator.navigateToPracticeFromHome
    }
}

extension PracticeCoordinator: PracticeHomeViewControllerDelegate {
    func practiceHomeViewController(_ vc: PracticeHomeViewController, didSelectPracticeSet practiceSet: PracticeSet, forTrack track: Track) {
        appCoordinator?.navigateToPracticeFromHome(track: track, practiceSet: practiceSet)
    }
}

