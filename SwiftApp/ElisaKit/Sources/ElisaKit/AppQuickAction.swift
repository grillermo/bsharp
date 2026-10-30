import Foundation

/// Home Screen quick actions the app registers at launch (touch and hold the
/// icon). Each raw value is the `UIApplicationShortcutItem.type`.
public enum AppQuickAction: String, Equatable, Sendable {
    case installLatest = "me.chiq.elisa-musica.install-latest"

    /// Info.plist key that `./deploy` fills with the pinned OTA manifest URL.
    public static let otaManifestURLInfoKey = "ElisaMusicaOTAManifestURL"

    public init?(shortcutType: String) {
        self.init(rawValue: shortcutType)
    }

    /// Builds made outside `./deploy` carry no manifest URL, so they offer no
    /// Install Latest: there is no release for them to install.
    public static func available(infoDictionary: [String: Any]?) -> [AppQuickAction] {
        otaManifestURL(infoDictionary: infoDictionary) == nil ? [] : [.installLatest]
    }

    public func url(infoDictionary: [String: Any]?) -> URL? {
        switch self {
        case .installLatest:
            // The install page's button link. ./deploy republishes the manifest
            // under the same name every release, so it installs the newest build.
            Self.otaManifestURL(infoDictionary: infoDictionary).flatMap {
                URL(string: "itms-services://?action=download-manifest&url=\($0.absoluteString)")
            }
        }
    }

    private static func otaManifestURL(infoDictionary: [String: Any]?) -> URL? {
        guard let value = infoDictionary?[otaManifestURLInfoKey] as? String,
              let url = URL(string: value.trimmingCharacters(in: .whitespaces)),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              url.host?.isEmpty == false
        else { return nil }
        return url
    }
}
