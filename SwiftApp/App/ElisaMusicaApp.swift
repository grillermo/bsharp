import ElisaKit
import SwiftUI
import UIKit

@main
struct ElisaMusicaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    /// Made once, here: a view's @State initial value can be evaluated again, and the model
    /// decodes all the audio.
    @State private var model = GameModel()

    var body: some Scene {
        WindowGroup {
            HomeView(model: model)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        QuickActions.register(application)
        DevLog.event("app.launch", ["quickActions": "\(application.shortcutItems?.count ?? 0)"])
        return true
    }

    /// Installs the scene delegate that handles Home Screen quick actions, both at cold launch
    /// and while running.
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = QuickActionSceneDelegate.self
        }
        return configuration
    }
}
