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
    private weak var practiceViewController: PracticeViewController?

    init(container: AppContainer, appCoordinator: AppCoordinator) {
        self.container = container
        self.appCoordinator = appCoordinator
    }

    func start() -> UINavigationController {
        let vc = PracticeViewController(
            settings: container.settings,
            libraryService: container.libraryService,
            clipService: container.clipService,
            audioPlayer: container.audioPlayer,
            practiceService: container.practiceService
        )
        vc.title = "Practice"
        vc.delegate = self
        self.practiceViewController = vc
        navigationController.viewControllers = [vc]
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }
    
    func loadPracticeSet(track: Track, practiceSet: PracticeSet) {
        practiceViewController?.loadTrackAndPracticeSet(track: track, practiceSet: practiceSet)
    }
}

extension PracticeCoordinator: PracticeViewControllerDelegate {
    func practiceViewController(_ vc: PracticeViewController, didTapTrackTitle track: Track) {
        appCoordinator?.switchToLibraryWithTrack(track)
    }
}

