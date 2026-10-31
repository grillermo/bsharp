import SwiftUI

/// The web app's pill buttons (.button): Hello Headline, white on ink, darker while pressed.
struct PillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.headline(20))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Capsule().fill(configuration.isPressed ? Theme.inkPressed : Theme.ink))
            .opacity(isEnabled ? 1 : 0.4)
    }
}
