import SwiftUI

/// The round play button. The web app's next button is not drawn: it was never enabled.
struct ControlsBar: View {
    let buttonSize: CGFloat
    let iconSize: CGFloat
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            Image(systemName: "play.fill").font(.system(size: iconSize, weight: .black))
        }
        .buttonStyle(RoundButtonStyle(size: buttonSize))
        .accessibilityIdentifier("play-button")
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
        ZStack {
            // CSS box-shadows paint only outside the border box, so they must not show through
            // the dimmed next button's translucent face.
            ZStack {
                Circle().fill(Theme.inkPressed).offset(y: pressed ? 2 : 6)
                Circle().fill(.black.opacity(0.15)).blur(radius: 6).offset(y: 12)
            }
            .frame(width: size, height: size)
            .mask { CircleHole(diameter: size).fill(style: FillStyle(eoFill: true)).frame(width: size * 3, height: size * 3) }
            Circle().fill(Theme.ink).frame(width: size, height: size)
            label().foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .offset(y: pressed ? 4 : 0)
        .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

/// A big rectangle with a circle cut out (fill with the even-odd rule).
struct CircleHole: Shape {
    let diameter: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addEllipse(in: CGRect(x: rect.midX - diameter / 2, y: rect.midY - diameter / 2,
                                   width: diameter, height: diameter))
        return path
    }
}
