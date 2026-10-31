import Testing
@testable import ElisaKit

@Suite struct ProfileIconsTests {
    @Test func theNineIconsInTheFormsOrder() {
        #expect(ProfileIcons.all == ["fa-user", "fa-truck", "fa-bolt", "fa-paw", "fa-soccer-ball-o",
                                     "fa-smile-o", "fa-umbrella", "fa-trophy", "fa-taxi"])
    }

    @Test func eachHasItsOwnSymbol() {
        let symbols = ProfileIcons.all.map(ProfileIcons.symbol(for:))
        #expect(Set(symbols).count == 9)
        #expect(ProfileIcons.symbol(for: "fa-paw") == "pawprint.fill")
    }

    @Test func anUnknownIconIsAPerson() {
        #expect(ProfileIcons.symbol(for: "fa-rocket") == "person.fill")
    }
}
