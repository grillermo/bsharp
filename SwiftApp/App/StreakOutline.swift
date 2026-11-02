import ElisaKit
import SwiftUI

/// The snake round the screen edge that grows clockwise from the top centre as the streak grows
/// (SnakeLayout). A hit grows it slowly, a miss unwinds it fast.
struct StreakOutline: View {
    let streak: Int
    /// The head's stop now; it steps towards the streak's stop.
    @State private var shown = 0

    var body: some View {
        GeometryReader { geo in
            let layout = SnakeLayout(width: geo.size.width, height: geo.size.height,
                                     thickness: SnakeLayout.thickness)
            let target = layout.stop(forProgress: Streak.progress(streak))
            ZStack(alignment: .topLeading) {
                let pieces = layout.pieces(atStop: shown)
                ForEach(pieces.indices, id: \.self) { index in
                    SnakePiece(piece: pieces[index], scale: layout.scale)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            // Starts at the tail and head alone, so the saved streak fills in at launch as the
            // outline it replaces did. A rotation changes the stops, hence the size in the id.
            .task(id: Grow(target: target, width: geo.size.width, height: geo.size.height)) {
                await grow(to: target, last: layout.lastStop)
            }
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

    private struct Grow: Equatable {
        let target: Int
        let width: Double
        let height: Double
    }

    private func grow(to target: Int, last: Int) async {
        shown = min(shown, last)
        let steps = abs(target - shown)
        guard steps > 0 else { return }
        let duration = target < shown ? 0.35 : 0.9
        let pause = Duration.seconds(duration / Double(steps))
        while shown != target {
            shown += target > shown ? 1 : -1
            try? await Task.sleep(for: pause)
            if Task.isCancelled { return }
        }
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
