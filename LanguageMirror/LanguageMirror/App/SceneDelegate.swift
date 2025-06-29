//
//  SceneDelegate.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//

import UIKit



class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
        
        
        guard let windowScene = scene as? UIWindowScene else { return }

        
       
        // Select the project file in the Navigator (the one with the blue icon).
        // Select your target under the “Targets” section.
        // Go to the Build Settings tab.
        // In the search bar, type Swift Compiler - Custom Flags.
        // Under the section “Swift Compiler - Custom Flags”, you will find a field named Other Swift Flags.
        // This is where you can add custom flags that will be passed to the Swift compiler.
        
        // If it is not already there, add"
        // -D DEBUG
        
        // #if DEBUG
        //     DataManager.shared.loadMock()
        //     UserDataManager.shared.loadMock()
        // #else
        //     try? DataManager.shared.load()
        //     try? UserDataManager.shared.load()
        // #endif
        
        
        if false {
            DataManager.shared.loadMock()
            UserDataManager.shared.loadMock()
        } else {
            
            do {
                try DataManager.shared.load()
                try UserDataManager.shared.load()
            } catch {
                // You decide how to react: assert, alert, or fall back to mock data.
                fatalError("❌ Startup data load failed: \(error)")
            }
        }
        
        // Library tab
        let rootViewController = CollectionListViewController()
        let audioRecorderViewController = RecorderViewController()
        
        let nav = UINavigationController(rootViewController: audioRecorderViewController)
        nav.tabBarItem = UITabBarItem(title: "Library",
                                      image: UIImage(systemName: "book"),
                                      tag: 0)

        // Assemble tab bar
        let tabBar = UITabBarController()
        tabBar.viewControllers = [nav]

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = tabBar
        window?.makeKeyAndVisible()
        
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Save changes in the application's managed object context when the application transitions to the background.
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }


}

