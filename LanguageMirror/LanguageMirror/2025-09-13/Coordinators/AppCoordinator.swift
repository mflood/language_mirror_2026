//
//  AppCoordinator.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

@MainActor
final class AppCoordinator: NSObject, UITabBarControllerDelegate {
    private let window: UIWindow
    private let container: AppContainer
    private let tabBarController = UITabBarController()

    private var coordinators: [Coordinator] = []
    
    // Store coordinator references for cross-tab navigation
    private var libraryCoordinator: LibraryCoordinator?
    private var practiceCoordinator: PracticeCoordinator?
    
    // token for observing library changes
    // Non-isolated storage for the token
    private let tokenBox = NotificationTokenBox()
    
    // Track if we're processing pending imports
    private var isProcessingPendingImports = false
    
    init(window: UIWindow, container: AppContainer) {
        self.window = window
        self.container = container
        super.init()
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
        
        let libraryCoordinator = LibraryCoordinator(container: container, appCoordinator: self)
        let importCoordinator  = ImportCoordinator(container: container)
        let practiceCoordinator = PracticeCoordinator(container: container, appCoordinator: self)
        let settingsCoordinator = SettingsCoordinator(container: container)
        
        // Store references for cross-tab navigation
        self.libraryCoordinator = libraryCoordinator
        self.practiceCoordinator = practiceCoordinator
        
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
        tabBarController.delegate = self
        
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
            
            // Highlight the newly added track if we have the track ID
            if let trackId = note.userInfo?["trackID"] as? String {
                self.highlightTrackInLibrary(trackId: trackId)
            }
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
    
    // MARK: - Track Highlighting
    
    private func highlightTrackInLibrary(trackId: String) {
        // Find the Library view controller and highlight the track
        if let libraryNav = tabBarController.viewControllers?[0] as? UINavigationController,
           let libraryVC = libraryNav.viewControllers.first as? LibraryViewController {
            libraryVC.highlightTrack(withId: trackId)
        }
    }
    
    // MARK: - Cross-Tab Navigation
    
    func switchToLibraryWithTrack(_ track: Track) {
        // Switch to Library tab (index 0)
        tabBarController.selectedIndex = 0
        
        // Push TrackDetailViewController onto Library navigation stack
        libraryCoordinator?.showTrackDetail(for: track)
    }
    
    func switchToPracticeWithSet(track: Track, practiceSet: PracticeSet) {
        // Switch to Practice tab (index 2)
        tabBarController.selectedIndex = 2
        
        // Load practice set in PracticeViewController
        practiceCoordinator?.loadPracticeSet(track: track, practiceSet: practiceSet)
    }
    
    func practiceSessionStartedFromLibrary(track: Track, practiceSet: PracticeSet) {
        // Update Practice tab's view to show this session without switching tabs
        // This keeps both views in sync when practice is started from Library flow
        practiceCoordinator?.loadPracticeSet(track: track, practiceSet: practiceSet)
    }
    
    func navigateToPracticeFromHome(track: Track, practiceSet: PracticeSet) {
        // Switch to Library tab first
        tabBarController.selectedIndex = 0
        
        // Push TrackDetailViewController, then push PracticeViewController
        libraryCoordinator?.showTrackDetailAndPractice(for: track, practiceSet: practiceSet)
    }
    
    // MARK: - UITabBarControllerDelegate
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        // Stop practice playback when Practice tab is selected
        if tabBarController.selectedIndex == 2 { // Practice tab index
            stopPracticePlaybackInAllNavigationStacks()
        }
    }
    
    private func stopPracticePlaybackInAllNavigationStacks() {
        // Check all navigation controllers for PracticeViewController instances
        for viewController in tabBarController.viewControllers ?? [] {
            if let navController = viewController as? UINavigationController {
                stopPracticePlaybackInNavigationStack(navController)
            }
        }
    }
    
    private func stopPracticePlaybackInNavigationStack(_ navigationController: UINavigationController) {
        // Check all view controllers in the navigation stack
        for viewController in navigationController.viewControllers {
            if let practiceVC = viewController as? PracticeViewController {
                practiceVC.stopCurrentPlayback()
            }
        }
    }
}
