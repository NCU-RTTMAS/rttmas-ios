//
//  SceneDelegate.swift
//  YOLO
//
//  Created by Quisette Chung on 2025/2/27.
//  Copyright © 2025 Ultralytics. All rights reserved.
//// SceneDelegate.swift
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)

        // Load the storyboard
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let navController = storyboard.instantiateInitialViewController() as! UINavigationController
        window.rootViewController = navController
        
        self.window = window
        window.makeKeyAndVisible()
        
        print("SceneDelegate: Storyboard loaded with navigation controller")
    }
}
