//
//  AppCoordinator.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

@MainActor
final class AppCoordinator {
    private let window: UIWindow
    private let container: AppContainer
    private let tabBarController = UITabBarController()

    private var coordinators: [Coordinator] = []
    
    // token for observing library changes
    // Non-isolated storage for the token
    private let tokenBox = NotificationTokenBox()
    
    // Track if we're processing pending imports
    private var isProcessingPendingImports = false
    
    init(window: UIWindow, container: AppContainer) {
        self.window = window
        self.container = container
        self.startObserving()
    }
    
    deinit {
        let center = NotificationCenter.default
        if let t = tokenBox.token {
            center.removeObserver(t);
            tokenBox.token = nil }
    }
    
    func start() {
        // Child coordinators
        
        let libraryCoordinator = LibraryCoordinator(container: container)
        let importCoordinator  = ImportCoordinator(container: container)
        let practiceCoordinator = PracticeCoordinator(container: container)
        let settingsCoordinator = SettingsCoordinator(container: container)
        
        self.coordinators = [libraryCoordinator, importCoordinator, practiceCoordinator, settingsCoordinator]
        
        let libraryNav  = libraryCoordinator.start()
        libraryNav.tabBarItem  = UITabBarItem(title: "Library",
                                              image: UIImage(systemName: "books.vertical"),
                                              tag: 0)

        let importNav   = importCoordinator.start()
        importNav.tabBarItem   = UITabBarItem(title: "Import",
                                              image: UIImage(systemName: "square.and.arrow.down"),
                                              tag: 1)

        let practiceNav = practiceCoordinator.start()
        practiceNav.tabBarItem = UITabBarItem(title: "Practice",
                                              image: UIImage(systemName: "repeat"),
                                              tag: 2)

        let settingsNav = settingsCoordinator.start()
        settingsNav.tabBarItem = UITabBarItem(title: "Settings",
                                              image: UIImage(systemName: "gearshape"),
                                              tag: 3)

        tabBarController.viewControllers = [libraryNav, importNav, practiceNav, settingsNav]
        
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        
        // Check for pending imports from Share Extension
        Task {
            await checkForPendingImports()
        }
    }
    
    func startObserving() {
        guard tokenBox.token == nil else { return }
        
        let center = NotificationCenter.default
        tokenBox.token = center.addObserver(forName: .libraryDidAddTrack, object: nil, queue: .main) {
            [weak self] note in
            guard let self = self else { return }
            self.tabBarController.selectedIndex = 0
        }
    }
    
    // MARK: - Pending Imports from Share Extension
    
    private func checkForPendingImports() async {
        guard !isProcessingPendingImports else { return }
        isProcessingPendingImports = true
        defer { isProcessingPendingImports = false }
        
        let pendingImports = SharedImportManager.retrievePendingImports()
        guard !pendingImports.isEmpty else { return }
        
        // Process each pending import
        for pendingImport in pendingImports {
            do {
                // Import the file using the import service
                _ = try await container.importService.performImport(source: .audioFile(url: pendingImport.fileURL))
                
                // Clean up after successful import
                SharedImportManager.deleteSharedFile(at: pendingImport.fileURL)
                SharedImportManager.clearPendingImport(id: pendingImport.id)
                
            } catch {
                print("Failed to import shared file: \(error.localizedDescription)")
                // Clear the failed import to prevent retry loops
                SharedImportManager.clearPendingImport(id: pendingImport.id)
                SharedImportManager.deleteSharedFile(at: pendingImport.fileURL)
            }
        }
        
        // If we imported at least one file, switch to Library tab
        if !pendingImports.isEmpty {
            tabBarController.selectedIndex = 0
        }
    }
}
