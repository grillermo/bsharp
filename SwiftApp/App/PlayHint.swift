import SwiftUI

/// The first-run hint: an arrow down at the play button and no text, since she can't read yet.
struct PlayHint: View {
    let buttonSize: CGFloat
    let arrowSize: CGFloat

    var body: some View {
        Text("↓")
            .font(.system(size: arrowSize))
            .foregroundStyle(Theme.ink)
            .frame(width: buttonSize, height: arrowSize)
            .accessibilityIdentifier("play-hint")
    }
}
