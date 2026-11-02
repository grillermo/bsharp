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

    @Test(arguments: screens) func theHeadStaysOnScreen(width: Double, height: Double) {
        let layout = SnakeLayout(width: width, height: height, thickness: SnakeLayout.thickness)
        for stop in 0...layout.lastStop {
            let head = layout.pieces(atStop: stop).last!
            #expect(head.kind == .head)
            // The nose end of the head, before the piece's own rotation.
            let radians = head.rotation * .pi / 180
            let noseX = head.x + cos(radians) * SnakeLayout.headLength * layout.scale
            let noseY = head.y + sin(radians) * SnakeLayout.headLength * layout.scale
            #expect(noseX >= -0.01 && noseX <= width + 0.01)
            #expect(noseY >= -0.01 && noseY <= height + 0.01)
        }
    }

    @Test func aFullStreakClosesTheLoopAtTheTail() {
        let layout = SnakeLayout(width: 390, height: 844, thickness: 26)
        let head = layout.pieces(atStop: layout.stop(forProgress: 1)).last!
        #expect(abs(head.x + SnakeLayout.headLength * layout.scale - 195) < 0.01)
        #expect(head.y == 0)
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
