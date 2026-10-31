import ElisaKit
import UIKit

/// The character cut-outs, bundled from static/characters/ at `characters/<name>.png`.
@MainActor
enum CharacterImages {
    private static var cache: [String: UIImage] = [:]

    static func image(_ name: String) -> UIImage? {
        if let cached = cache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "characters"),
              let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) else { return nil }
        let ready = image.preparingForDisplay() ?? image
        cache[name] = ready
        return ready
    }

    /// Reads and decodes every image up front, so a reveal never waits on the disk.
    static func preload() {
        for name in Characters.all {
            _ = image(name)
        }
    }
}
