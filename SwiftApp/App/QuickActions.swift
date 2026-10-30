import UIKit
import ElisaKit

enum QuickActions {
    /// Offers Install Latest on the Home Screen icon, only in builds made by
    /// ./deploy (they carry the manifest URL).
    @MainActor static func register(_ application: UIApplication) {
        application.shortcutItems = AppQuickAction.available(infoDictionary: Bundle.main.infoDictionary).map { action in
            switch action {
            case .installLatest:
                UIApplicationShortcutItem(
                    type: action.rawValue,
                    localizedTitle: "Install Latest",
                    localizedSubtitle: nil,
                    icon: UIApplicationShortcutIcon(systemImageName: "arrow.down.app")
                )
            }
        }
    }
}

/// Receives quick actions for SwiftUI's window scene. SwiftUI still owns the
/// window; this delegate only handles the shortcut item.
final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    // A cold launch delivers the item before the scene is active, and opening a
    // URL then is unreliable, so it waits for the first activation.
    private var pendingAction: AppQuickAction?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        pendingAction = connectionOptions.shortcutItem.flatMap { AppQuickAction(shortcutType: $0.type) }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard let action = pendingAction else { return }
        pendingAction = nil
        perform(action)
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        guard let action = AppQuickAction(shortcutType: shortcutItem.type) else {
            completionHandler(false)
            return
        }
        perform(action)
        completionHandler(true)
    }

    private func perform(_ action: AppQuickAction) {
        guard let url = action.url(infoDictionary: Bundle.main.infoDictionary) else { return }
        UIApplication.shared.open(url) { opened in
            DevLog.event("quickaction", ["type": action.rawValue, "opened": "\(opened)"])
            guard opened, action == .installLatest else { return }
            // iOS swaps the bundle under a running app, which crashes it, and
            // only starts installing once the user leaves. Exiting after the
            // install prompt is up lets the install begin on its own.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { exit(0) }
        }
    }
}
