import SwiftUI

/// The first-run hint: an arrow up at the play button and no text, since she can't read yet.
/// Laid out like ControlsBar so the arrow sits under the play button.
struct PlayHint: View {
    let buttonSize: CGFloat
    let spacing: CGFloat
    let arrowSize: CGFloat

    var body: some View {
        HStack(spacing: spacing) {
            Text("↑")
                .font(.system(size: arrowSize))
                .foregroundStyle(Theme.ink)
                .frame(width: buttonSize, height: arrowSize)
                .accessibilityIdentifier("play-hint")
            Color.clear.frame(width: buttonSize, height: 1)
        }
    }
}
