import ElisaKit
import SwiftUI

/// A Bluey character and its name pill, popped in beside the play and next buttons for the
/// length of a right answer's reveal (#character-reveal in _bluey.scss).
struct CharacterReveal: View {
    let name: String
    let metrics: Metrics
    @State private var shown = false

    var body: some View {
        VStack(spacing: 4) {
            if let image = CharacterImages.image(name) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    // The img box is as wide as the picture at that height (capped by max-width),
                    // so the character sits flush with `right` instead of centred in a wide box.
                    .frame(width: min(metrics.revealImageHeight * image.size.width / max(image.size.height, 1),
                                      metrics.revealImageMaxWidth),
                           height: metrics.revealImageHeight)
                    .shadow(color: Theme.ink.opacity(0.35), radius: 6, y: 6)
            }
            Text(Characters.label(name))
                .font(Theme.headline(metrics.revealNameFont))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 18)
                .padding(.top, 2)
                .padding(.bottom, 4)
                .background(RoundedRectangle(cornerRadius: 20).fill(.white))
                // The 4 pt pale-blue ring (box-shadow: 0 0 0 4px $bluey-edge).
                .background(RoundedRectangle(cornerRadius: 24).fill(Theme.edge).padding(-4))
        }
        // transform: scale(0.6) rotate(-4deg) → none over 0.35 s on cubic-bezier(.3, 1.5, .5, 1),
        // and opacity over 0.25 s.
        .scaleEffect(shown ? 1 : 0.6)
        .rotationEffect(.degrees(shown ? 0 : -4))
        .animation(.timingCurve(0.3, 1.5, 0.5, 1, duration: 0.35), value: shown)
        .opacity(shown ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: shown)
        .onAppear { shown = true }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("character-reveal")
        .accessibilityLabel(Characters.label(name))
    }
}
