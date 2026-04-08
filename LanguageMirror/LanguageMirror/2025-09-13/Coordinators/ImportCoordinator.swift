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

    private var importViewController: ImportViewController?

    func start() -> UINavigationController {
        let vc = ImportViewController(
            importService: container.importService,
            featuredCatalog: container.featuredCatalog
        )
        vc.title = L10n("tab.import")
        self.importViewController = vc
        navigationController.viewControllers = [vc]
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    /// Programmatically trigger a bundle manifest import (called from URL scheme handling)
    func importBundle(from manifestURL: URL) {
        // Pop to root so the import progress shows cleanly
        navigationController.popToRootViewController(animated: false)
        // Dismiss any presented view controllers (e.g. alerts, pickers)
        navigationController.presentedViewController?.dismiss(animated: false)
        importViewController?.importBundleFromURL(manifestURL)
    }

    deinit {
        print("ImportCoordinator deinit") }
}
