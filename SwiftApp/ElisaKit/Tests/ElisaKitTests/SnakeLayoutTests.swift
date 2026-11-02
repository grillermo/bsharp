import Foundation
import Testing
@testable import ElisaKit

@Suite struct SnakeLayoutTests {
    static let screens: [(Double, Double)] = [
        (390, 844), (844, 390), // iPhone 16e
        (744, 1133), (1133, 744), // iPad mini
        (820, 1180), (1180, 820), // iPad Air
    ]

    @Test(arguments: screens) func everyHitGrowsTheSnake(width: Double, height: Double) {
        let layout = SnakeLayout(width: width, height: height, thickness: SnakeLayout.thickness)
        let stops = (0...Streak.target).map { layout.stop(forProgress: Streak.progress($0)) }
        for (before, after) in zip(stops, stops.dropFirst()) {
            #expect(after > before)
        }
    }

    /// The head's nose end, from the piece's turn around its top-left corner.
    static func nose(_ head: SnakeLayout.Piece, _ layout: SnakeLayout) -> (x: Double, y: Double) {
        let radians = head.rotation * .pi / 180
        let length = SnakeLayout.headLength * layout.scale
        return (head.x + cos(radians) * length - sin(radians) * layout.edgeOffset,
                head.y + sin(radians) * length + cos(radians) * layout.edgeOffset)
    }

    @Test(arguments: screens) func theHeadStaysOnScreenAllTheWayRound(width: Double, height: Double) {
        let layout = SnakeLayout(width: width, height: height, thickness: SnakeLayout.thickness)
        for step in 0...2000 {
            let position = Double(layout.lastStop) * Double(step) / 2000
            let nose = Self.nose(layout.head(atDistance: layout.distance(atStop: position)), layout)
            #expect(nose.x >= -0.01 && nose.x <= width + 0.01)
            #expect(nose.y >= -0.01 && nose.y <= height + 0.01)
        }
    }

    @Test(arguments: screens) func theHeadMovesWithoutJumps(width: Double, height: Double) {
        let layout = SnakeLayout(width: width, height: height, thickness: SnakeLayout.thickness)
        var before = layout.head(atDistance: layout.distance(atStop: 0))
        let steps = 4000.0
        for step in 1...Int(steps) {
            let head = layout.head(atDistance: layout.distance(atStop: Double(layout.lastStop) * Double(step) / steps))
            var turn = abs(head.rotation - before.rotation).truncatingRemainder(dividingBy: 360)
            turn = min(turn, 360 - turn)
            #expect(hypot(head.x - before.x, head.y - before.y) < 8)
            #expect(turn < 8)
            before = head
        }
    }

    @Test func theHeadRestsFlatAgainstTheEdge() {
        let layout = SnakeLayout(width: 390, height: 844, thickness: 26)
        let start = layout.head(atDistance: layout.distance(atStop: 0))
        #expect(abs(start.x - (195 + 65)) < 0.01 && abs(start.y) < 0.01 && abs(start.rotation) < 0.01)
        let right = layout.head(atDistance: layout.distance(atStop: 8))
        #expect(abs(right.x - 390) < 0.01 && abs(right.rotation - 90) < 0.01)
    }

    @Test func aFullStreakClosesTheLoopAtTheTail() {
        let layout = SnakeLayout(width: 390, height: 844, thickness: 26)
        let head = layout.head(atDistance: layout.distance(atStop: Double(layout.stop(forProgress: 1))))
        #expect(abs(head.x + SnakeLayout.headLength * layout.scale - 195) < 0.01)
        #expect(abs(head.y) < 0.01)
    }

    @Test func aStreakPastTheTargetStaysFull() {
        let layout = SnakeLayout(width: 390, height: 844, thickness: 26)
        #expect(layout.stop(forProgress: Streak.progress(35)) == layout.lastStop)
    }

    @Test func theScreenKeepsRoomForTheSnakeAndTheAir() {
        // A notched top already clears it; a home-button edge needs the whole clearance.
        #expect(SnakeLayout.contentInset(safeArea: 47) == 0)
        #expect(SnakeLayout.contentInset(safeArea: 0) == SnakeLayout.clearance)
        #expect(SnakeLayout.contentInset(safeArea: 20) == SnakeLayout.clearance - 20)
    }
}
