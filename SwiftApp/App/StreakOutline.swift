import ElisaKit
import SwiftUI

/// The outline round the screen that fills clockwise from the top centre as the streak grows
/// (#streak-outline in _bluey.scss, streak.ts). A hit fills it slowly, a miss unwinds it fast.
struct StreakOutline: View {
    let streak: Int
    /// The fraction of the way round that is drawn now; it animates towards the streak.
    @State private var shown = 0.0

    private static let stroke = StrokeStyle(lineWidth: 5, lineJoin: .round)

    var body: some View {
        ZStack {
            OutlineShape().stroke(.white.opacity(0.55), style: Self.stroke)
            OutlineShape().trim(from: 0, to: shown).stroke(Theme.ink, style: Self.stroke)
        }
        .allowsHitTesting(false)
        // initial: true draws the saved streak at launch, filling from empty as the web app does.
        .onChange(of: streak, initial: true) { _, new in
            let progress = Streak.progress(new)
            withAnimation(.easeInOut(duration: progress < shown ? 0.35 : 0.9)) {
                shown = progress
            }
        }
        .accessibilityHidden(true)
        // A full-screen accessibility element would shadow the hit testing of the scroll views
        // under it (XCUITest reports their contents as not hittable), so the value lives on a
        // one-point element in the corner.
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("streak-outline")
                .accessibilityValue("\(streak)")
        }
    }
}

/// A rectangle 3 pt inside the screen edge, drawn from the top centre clockwise, so a trim of
/// 0...1 is the share of the way round (the web app's pathLength=1).
private struct OutlineShape: Shape {
    static let inset: CGFloat = 3

    func path(in rect: CGRect) -> Path {
        let left = rect.minX + Self.inset
        let top = rect.minY + Self.inset
        let right = rect.maxX - Self.inset
        let bottom = rect.maxY - Self.inset
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: top))
        path.addLine(to: CGPoint(x: right, y: top))
        path.addLine(to: CGPoint(x: right, y: bottom))
        path.addLine(to: CGPoint(x: left, y: bottom))
        path.addLine(to: CGPoint(x: left, y: top))
        path.addLine(to: CGPoint(x: rect.midX, y: top))
        return path
    }
}
