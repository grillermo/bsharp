import Testing
@testable import ElisaKit

@Suite struct TapUnlockTests {
    @Test func theSixthQuickTapUnlocks() {
        var unlock = TapUnlock()
        let results = (0..<6).map { unlock.tap(at: Double($0)) }
        #expect(results == [false, false, false, false, false, true])
    }

    @Test func aPauseStartsTheCountOver() {
        var unlock = TapUnlock()
        for i in 0..<5 { _ = unlock.tap(at: Double(i)) }
        let afterPause = unlock.tap(at: 6.6)
        #expect(!afterPause)
        let next = (0..<4).map { unlock.tap(at: 7 + Double($0)) }
        #expect(next == [false, false, false, false])
        let sixth = unlock.tap(at: 11)
        #expect(sixth)
    }

    @Test func afterUnlockingItNeedsSixMore() {
        var unlock = TapUnlock()
        for i in 0..<6 { _ = unlock.tap(at: Double(i)) }
        let again = unlock.tap(at: 6)
        #expect(!again)
    }
}
