import Testing
@testable import ElisaKit

@Suite struct FlagLayoutTests {
    @Test func portraitWidensAsFlagsAreAdded() {
        #expect(FlagLayout.columns(count: 2, landscape: false) == 1)
        #expect(FlagLayout.columns(count: 3, landscape: false) == 1)
        #expect(FlagLayout.columns(count: 4, landscape: false) == 2)
        #expect(FlagLayout.columns(count: 9, landscape: false) == 2)
        #expect(FlagLayout.columns(count: 10, landscape: false) == 3)
        #expect(FlagLayout.columns(count: 14, landscape: false) == 3)
    }

    @Test func landscapeHasMoreColumns() {
        #expect(FlagLayout.columns(count: 2, landscape: true) == 3)
        #expect(FlagLayout.columns(count: 9, landscape: true) == 3)
        #expect(FlagLayout.columns(count: 10, landscape: true) == 5)
    }
}
