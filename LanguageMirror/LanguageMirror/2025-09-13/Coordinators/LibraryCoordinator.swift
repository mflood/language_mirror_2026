//
//  LibraryCoordinator.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

@MainActor
final class LibraryCoordinator: Coordinator {
    let navigationController = UINavigationController()
    private let container: AppContainer
    private weak var appCoordinator: AppCoordinator?
    
    init(container: AppContainer, appCoordinator: AppCoordinator) {
        self.container = container
        self.appCoordinator = appCoordinator
    }

    func start() -> UINavigationController {
        let vc = LibraryViewController(service: container.libraryService)
        // self.viewController = vc
        vc.title = "Library"
        vc.delegate = self
        navigationController.viewControllers = [vc]
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }
    
    deinit {
        print("LibraryCoordinator deinit")
    }
    
    func showTrackDetail(for track: Track) {
        let detail = TrackDetailViewController(
            track: track,
            audioPlayer: container.audioPlayer,
            clipService: container.clipService,
            settings: container.settings
        )
        detail.delegate = self
        navigationController.pushViewController(detail, animated: true)
    }
}

extension LibraryCoordinator: LibraryViewControllerDelegate {
    func libraryViewController(_ vc: LibraryViewController, didSelect track: Track) {
        let detail = TrackDetailViewController(
            track: track,
            audioPlayer: container.audioPlayer,
            clipService: container.clipService,
            settings: container.settings
        )
        detail.delegate = self
        navigationController.pushViewController(detail, animated: true)
    }
}

extension LibraryCoordinator: TrackDetailViewControllerDelegate {
    func trackDetailViewController(_ vc: TrackDetailViewController, didSelectPracticeSet practiceSet: PracticeSet, forTrack track: Track) {
        appCoordinator?.switchToPracticeWithSet(track: track, practiceSet: practiceSet)
    }
}
