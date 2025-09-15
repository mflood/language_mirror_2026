//
//  LibraryCoordinator.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

final class LibraryCoordinator: Coordinator {
    let navigationController = UINavigationController()
    private let container: AppContainer
    // private var viewController: LibraryViewController!
    
    init(container: AppContainer) {
        
        self.container = container
        
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
        
        
        print("LibraryCoordinator deinit") }
    
}

extension LibraryCoordinator: LibraryViewControllerDelegate {
    func libraryViewController(_ vc: LibraryViewController, didSelect track: Track) {
        let detail = TrackDetailViewController(track: track, audioPlayer: container.audioPlayer)
        navigationController.pushViewController(detail, animated: true)
    }
}
