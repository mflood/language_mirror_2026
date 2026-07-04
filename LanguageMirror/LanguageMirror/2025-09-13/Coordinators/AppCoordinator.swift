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
    private var importCoordinator: ImportCoordinator?
    
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
        self.importCoordinator = importCoordinator
        self.practiceCoordinator = practiceCoordinator
        
        self.coordinators = [libraryCoordinator, importCoordinator, practiceCoordinator, settingsCoordinator]
        
        let libraryNav  = libraryCoordinator.start()
        libraryNav.tabBarItem  = UITabBarItem(title: L10n("tab.library"),
                                              image: UIImage(systemName: "books.vertical"),
                                              tag: 0)

        let importNav   = importCoordinator.start()
        importNav.tabBarItem   = UITabBarItem(title: L10n("tab.import"),
                                              image: UIImage(systemName: "square.and.arrow.down"),
                                              tag: 1)

        let practiceNav = practiceCoordinator.start()
        practiceNav.tabBarItem = UITabBarItem(title: L10n("tab.practice"),
                                              image: UIImage(systemName: "repeat"),
                                              tag: 2)

        let settingsNav = settingsCoordinator.start()
        settingsNav.tabBarItem = UITabBarItem(title: L10n("tab.settings"),
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

        // Install the embedded starter sample on first launch (or whenever
        // the library is empty and we haven't already tried).
        Task {
            await installStarterSampleIfNeeded()
        }

        // First launch: onboarding → auto-started first practice session.
        presentOnboardingIfNeeded()
    }

    // MARK: - Onboarding

    private static let onboardingCompletedKey = "onboarding.completed"
    static let learningLanguageKey = "onboarding.learningLanguage"

    private func presentOnboardingIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey) else { return }
        let onboarding = OnboardingViewController()
        onboarding.delegate = self
        onboarding.modalPresentationStyle = .fullScreen
        tabBarController.present(onboarding, animated: false)
    }

    /// Drop the brand-new user straight into a playing practice session:
    /// zero decisions between "I want to learn" and hearing the language.
    /// The starter import runs concurrently with onboarding, so poll briefly
    /// if the library hasn't been populated yet.
    private func autoStartFirstPractice(attempt: Int = 0) {
        let track = container.libraryService.listPacks().flatMap { $0.tracks }.first
        if let track,
           let set = track.practiceSets.max(by: { $0.clips.count < $1.clips.count }),
           !set.clips.isEmpty {
            tabBarController.selectedIndex = 0
            libraryCoordinator?.startPractice(track: track, practiceSet: set, autoPlay: true)
        } else if attempt < 20 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.autoStartFirstPractice(attempt: attempt + 1)
            }
        }
        // After 10s with no content (starter import failed), stay on Library —
        // never block the user on a spinner.
    }

    // MARK: - First-launch starter sample

    /// The bundle id of the embedded sample shipped under
    /// Resources/embedded_bundles/. Must match the iOS embed produced by
    /// sample_bundle_pipeline/4_embed_in_app.py.
    private static let starterBundleId = "starter_seoul_lunch"

    /// UserDefaults key remembering that we already attempted the auto-install.
    /// We never retry on this device once set, even if the user deletes the
    /// imported pack — we don't want surprise re-imports.
    private static let didInstallStarterKey = "appCoordinator.didInstallStarterSample"

    private func installStarterSampleIfNeeded() async {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Self.didInstallStarterKey) {
            return
        }
        // Only install if the library is currently empty.
        let packs = container.libraryService.listPacks()
        let hasAnyTracks = packs.contains { !$0.tracks.isEmpty }
        guard !hasAnyTracks else {
            // Library has content already (TestFlight tester returning, share
            // extension import, etc.) — mark as done so we never run.
            defaults.set(true, forKey: Self.didInstallStarterKey)
            return
        }

        do {
            print("🌱 [AppCoordinator] First launch: importing embedded starter sample '\(Self.starterBundleId)'...")
            let tracks = try await container.importService.performImport(
                source: .appBundleManifest(bundleId: Self.starterBundleId),
                progress: nil
            )
            print("✅ [AppCoordinator] Starter sample installed (\(tracks.count) tracks)")
            defaults.set(true, forKey: Self.didInstallStarterKey)
            // Notify the library so it refreshes; existing observer will handle the rest.
            if let firstId = tracks.first?.id {
                NotificationCenter.default.post(
                    name: .libraryDidAddTrack,
                    object: nil,
                    userInfo: ["trackID": firstId]
                )
            } else {
                NotificationCenter.default.post(name: .LibraryDidChange, object: nil)
            }
        } catch {
            // Don't set the flag on failure — let it retry next launch.
            print("⚠️ [AppCoordinator] Failed to install starter sample: \(error)")
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
                _ = try await container.importService.performImport(source: .audioFile(url: pendingImport.fileURL), progress: nil)
                
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
        
        // Always start from a clean Library stack when jumping in from another tab
        if let libraryNav = tabBarController.viewControllers?.first as? UINavigationController {
            libraryNav.popToRootViewController(animated: false)
        }
        
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
        
        // Reset Library navigation stack so we don't keep stacking flows
        if let libraryNav = tabBarController.viewControllers?.first as? UINavigationController {
            libraryNav.popToRootViewController(animated: false)
        }
        
        // Push TrackDetailViewController, then push PracticeViewController
        libraryCoordinator?.showTrackDetailAndPractice(for: track, practiceSet: practiceSet)
    }
    
    func switchToLibraryTab() {
        tabBarController.selectedIndex = 0
    }

    func switchToImportTab() {
        // Switch to Import tab (index 1)
        tabBarController.selectedIndex = 1
    }

    // MARK: - URL Scheme Handling

    /// Handle incoming URL (languagemirror://bundle?url=<encoded_manifest_url>)
    /// Returns true if the URL was handled.
    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        guard url.scheme == "languagemirror" else { return false }

        switch url.host {
        case "bundle":
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let manifestString = components.queryItems?.first(where: { $0.name == "url" })?.value,
                  let manifestURL = URL(string: manifestString) else {
                print("⚠️ [URLScheme] Missing or invalid 'url' parameter in: \(url)")
                return false
            }
            print("📦 [URLScheme] Importing bundle from: \(manifestURL)")
            importBundle(from: manifestURL)
            return true
        default:
            print("⚠️ [URLScheme] Unknown host: \(url.host ?? "nil")")
            return false
        }
    }

    private func importBundle(from manifestURL: URL) {
        // Switch to Import tab and trigger the import
        tabBarController.selectedIndex = 1
        importCoordinator?.importBundle(from: manifestURL)
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

// MARK: - OnboardingViewControllerDelegate

extension AppCoordinator: OnboardingViewControllerDelegate {
    func onboardingDidFinish(_ vc: OnboardingViewController, learningLanguage: String) {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Self.onboardingCompletedKey)
        defaults.set(learningLanguage, forKey: Self.learningLanguageKey)
        // Gentle first-session defaults: slowed audio is the whole point of
        // shadowing practice, and it's much less intimidating on day one.
        container.settings.simpleSpeed = 0.8
        vc.dismiss(animated: true) { [weak self] in
            self?.autoStartFirstPractice()
        }
    }

    func onboardingDidSkip(_ vc: OnboardingViewController) {
        UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
        vc.dismiss(animated: true)
    }
}
