import SwiftUI

/// Sky fading down to grass at 78% of the height, with three clouds: the body background of
/// the web app.
struct SkyBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                LinearGradient(stops: [
                    .init(color: Theme.skyTop, location: 0),
                    .init(color: Theme.skyBottom, location: 0.78),
                    .init(color: Theme.grass, location: 0.78),
                    .init(color: Theme.grassDark, location: 1),
                ], startPoint: .top, endPoint: .bottom)
                // The CSS clouds: `radial-gradient(ellipse RX% RY% at CX% CY%, #fff 60%, ...)`.
                cloud(cx: 0.18, cy: 0.09, rx: 0.22, ry: 0.06, in: geo.size)
                cloud(cx: 0.80, cy: 0.18, rx: 0.18, ry: 0.05, in: geo.size)
                cloud(cx: 0.55, cy: 0.04, rx: 0.14, ry: 0.04, in: geo.size)
            }
        }
        .ignoresSafeArea()
    }

    // White fills 60% of the gradient's radii, so the visible ellipse is 1.2 × radius across.
    private func cloud(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat, in size: CGSize) -> some View {
        Ellipse()
            .fill(.white)
            .frame(width: 1.2 * rx * size.width, height: 1.2 * ry * size.height)
            .position(x: cx * size.width, y: cy * size.height)
    }
}
