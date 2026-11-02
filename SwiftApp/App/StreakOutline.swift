import ElisaKit
import SwiftUI

/// The snake round the screen edge that grows clockwise from the top centre as the streak grows
/// (SnakeLayout). A hit grows it slowly, a miss unwinds it fast.
struct StreakOutline: View {
    let streak: Int
    /// The share of the stops the head has passed; it animates towards the streak's stop.
    @State private var shown = 0.0

    var body: some View {
        // The outer reader still sees the safe area, which tells a notch or island at the top.
        GeometryReader { safe in
            let gap = Self.cutoutGap(top: safe.safeAreaInsets.top)
            GeometryReader { geo in
                let layout = SnakeLayout(width: geo.size.width, height: geo.size.height,
                                         thickness: SnakeLayout.thickness, gap: gap)
                let target = Double(layout.stop(forProgress: Streak.progress(streak))) / Double(layout.lastStop)
                SnakeBody(width: geo.size.width, height: geo.size.height, gap: gap, shown: shown)
                    // initial: true fills the saved streak in at launch, as the old outline did.
                    .onChange(of: target, initial: true) { _, new in
                        withAnimation(.easeInOut(duration: new < shown ? 0.35 : 0.9)) { shown = new }
                    }
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
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

    /// A portrait iPhone with a tall top safe area has a camera cutout at the top centre; iPads
    /// (24) and home-button phones (20) don't, and in landscape the top inset is 0.
    private static func cutoutGap(top: CGFloat) -> Double {
        UIDevice.current.userInterfaceIdiom == .phone && top > 30 ? SnakeLayout.cutoutGap : 0
    }
}

/// The snake at one instant of the animation; SwiftUI calls `body` with each frame's `shown`.
private struct SnakeBody: View, Animatable {
    let width: CGFloat
    let height: CGFloat
    let gap: Double
    var shown: Double

    var animatableData: Double {
        get { shown }
        set { shown = newValue }
    }

    var body: some View {
        let layout = SnakeLayout(width: width, height: height, thickness: SnakeLayout.thickness, gap: gap)
        let neck = layout.distance(atStop: shown * Double(layout.lastStop))
        // The body ends a little under the head, so no gap shows at the neck.
        let reveal = min(1, (neck + 20 * layout.scale) / layout.pathLength)
        ZStack(alignment: .topLeading) {
            SnakePieces(width: width, height: height, gap: gap)
                .mask {
                    CentreLine(edge: layout.edgeOffset, radius: layout.cornerRadius, gap: gap)
                        .trim(from: 0, to: reveal)
                        .stroke(style: StrokeStyle(lineWidth: SnakeLayout.thickness * 1.1))
                }
            SnakePiece(piece: layout.tail, scale: layout.scale)
            SnakePiece(piece: layout.head(atDistance: neck), scale: layout.scale)
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }
}

/// The whole body of a full circle, flattened once so that only the mask over it changes per frame.
private struct SnakePieces: View {
    let width: CGFloat
    let height: CGFloat
    let gap: Double

    var body: some View {
        let layout = SnakeLayout(width: width, height: height, thickness: SnakeLayout.thickness, gap: gap)
        ZStack(alignment: .topLeading) {
            ForEach(layout.body.indices, id: \.self) { index in
                SnakePiece(piece: layout.body[index], scale: layout.scale)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .drawingGroup()
    }
}

/// The line the snake's middle follows: from beside the top centre, clockwise, back beside it.
private struct CentreLine: Shape {
    let edge: CGFloat
    let radius: CGFloat
    let gap: CGFloat

    func path(in rect: CGRect) -> Path {
        let left = rect.minX + edge, right = rect.maxX - edge
        let top = rect.minY + edge, bottom = rect.maxY - edge
        var path = Path()
        path.move(to: CGPoint(x: rect.midX + gap, y: top))
        path.addArc(tangent1End: CGPoint(x: right, y: top), tangent2End: CGPoint(x: right, y: bottom), radius: radius)
        path.addArc(tangent1End: CGPoint(x: right, y: bottom), tangent2End: CGPoint(x: left, y: bottom), radius: radius)
        path.addArc(tangent1End: CGPoint(x: left, y: bottom), tangent2End: CGPoint(x: left, y: top), radius: radius)
        path.addArc(tangent1End: CGPoint(x: left, y: top), tangent2End: CGPoint(x: right, y: top), radius: radius)
        path.addLine(to: CGPoint(x: rect.midX - gap, y: top))
        return path
    }
}

/// One piece, turned around its own top-left corner and moved into place.
private struct SnakePiece: View {
    let piece: SnakeLayout.Piece
    let scale: CGFloat

    var body: some View {
        let art = Self.art(piece.kind)
        Image(art.name)
            .resizable()
            .frame(width: art.width * scale * piece.stretch, height: art.height * scale)
            .rotationEffect(.degrees(piece.rotation), anchor: .topLeading)
            .offset(x: piece.x, y: piece.y)
    }

    private static func art(_ kind: SnakeLayout.Kind) -> (name: String, width: CGFloat, height: CGFloat) {
        switch kind {
        case .tail: ("snake-tail", 250, 100)
        case .segment: ("snake-segment", 200, 100)
        case .corner: ("snake-corner", 180, 180)
        case .head: ("snake-head", 272, 126)
        }
    }
}
