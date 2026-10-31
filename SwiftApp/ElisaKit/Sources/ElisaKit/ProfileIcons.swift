/// The profile icons. Saved progress keeps the web app's Fork Awesome ids; the app draws an
/// SF Symbol for each.
public enum ProfileIcons {
    /// In the settings form's order (index.html profile_icon_selector).
    public static let all = ["fa-user", "fa-truck", "fa-bolt", "fa-paw", "fa-soccer-ball-o",
                             "fa-smile-o", "fa-umbrella", "fa-trophy", "fa-taxi"]

    private static let symbols: [String: String] = [
        "fa-user": "person.fill",
        "fa-truck": "truck.box.fill",
        "fa-bolt": "bolt.fill",
        "fa-paw": "pawprint.fill",
        "fa-soccer-ball-o": "soccerball",
        "fa-smile-o": "face.smiling",
        "fa-umbrella": "umbrella.fill",
        "fa-trophy": "trophy.fill",
        "fa-taxi": "car.fill",
    ]

    /// The symbol for a saved icon id; a person for one this app doesn't know.
    public static func symbol(for icon: String) -> String {
        symbols[icon] ?? "person.fill"
    }
}
