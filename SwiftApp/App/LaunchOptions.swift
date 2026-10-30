import ElisaKit
import Foundation

/// Launch arguments for UI tests and screenshots, e.g.
/// `-ElisaFreshState YES -ElisaLevel gray -ElisaAnswer red`. A normal launch has none.
struct LaunchOptions {
    /// Start at this level (a chord id).
    var level: String?
    /// Always ask this chord, like the web app's __bsharp_test_deterministic_color.
    var answer: String?
    /// Play on a throwaway progress file, so a test never touches real progress.
    var freshState = false

    static func current(_ defaults: UserDefaults = .standard) -> LaunchOptions {
        LaunchOptions(level: defaults.string(forKey: "ElisaLevel"),
                      answer: defaults.string(forKey: "ElisaAnswer"),
                      freshState: defaults.bool(forKey: "ElisaFreshState"))
    }

    /// Where progress is kept. A fresh state gets a new temporary file on every call, so read
    /// it once.
    func progressURL() -> URL {
        freshState
            ? URL.temporaryDirectory.appending(path: "\(UUID().uuidString)/progress.json")
            : ProgressStore.defaultURL
    }
}
