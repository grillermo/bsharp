import SwiftUI

/// The round play and next buttons.
struct ControlsBar: View {
    let buttonSize: CGFloat
    let iconSize: CGFloat
    let spacing: CGFloat
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: spacing) {
            Button(action: onPlay) {
                Image(systemName: "play.fill").font(.system(size: iconSize, weight: .black))
            }
            .buttonStyle(RoundButtonStyle(size: buttonSize))
            .accessibilityIdentifier("play-button")
            // The web app never enables its next button (game.ts only ever adds .deactivated),
            // so it is drawn dimmed and does nothing.
            RoundButtonFace(size: buttonSize, pressed: false) {
                Image(systemName: "arrow.right").font(.system(size: iconSize, weight: .black))
            }
            .opacity(0.35)
            .accessibilityHidden(true)
        }
    }
}

struct RoundButtonStyle: ButtonStyle {
    let size: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        RoundButtonFace(size: size, pressed: configuration.isPressed) { configuration.label }
    }
}

/// An ink circle with a darker lower edge that sinks when pressed (div.controls a).
struct RoundButtonFace<Label: View>: View {
    let size: CGFloat
    let pressed: Bool
    @ViewBuilder let label: () -> Label

    var body: some View {
        Circle()
            .fill(Theme.ink)
            .frame(width: size, height: size)
            .overlay(label().foregroundStyle(.white))
            .shadow(color: Theme.inkPressed, radius: 0, y: pressed ? 2 : 6)
            .shadow(color: .black.opacity(0.15), radius: 10, y: 12)
            .offset(y: pressed ? 4 : 0)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}
