import SwiftUI

/// The white, slightly tilted card with the app's name (.title-card in _bluey.scss).
struct TitleCard: View {
    let fontSize: CGFloat

    var body: some View {
        Text("Elisa aprende música")
            .font(Theme.headline(fontSize))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .background(RoundedRectangle(cornerRadius: 28).fill(.white))
            // The 8 pt pale-blue ring (box-shadow: 0 0 0 8px $bluey-edge).
            .background(RoundedRectangle(cornerRadius: 36).fill(Theme.edge).padding(-8))
            .rotationEffect(.degrees(-3))
    }

    /// clamp(20px, min(6vw, 4.5vh), 56px)
    static func fontSize(for size: CGSize) -> CGFloat {
        min(56, max(20, min(size.width * 0.06, size.height * 0.045)))
    }
}
