import Testing
@testable import ElisaKit

@Suite struct KeepAwakeTests {
    @Test func onForFiveMinutesAfterTheLastPlayOrTap() {
        #expect(!KeepAwake.shouldKeepAwake(lastActivity: nil, now: 1000))
        #expect(KeepAwake.shouldKeepAwake(lastActivity: 1000, now: 1000))
        #expect(KeepAwake.shouldKeepAwake(lastActivity: 1000, now: 1299))
        #expect(!KeepAwake.shouldKeepAwake(lastActivity: 1000, now: 1300))
    }
}
