import Testing
@testable import ElisaKit

@Suite struct CharacterDeckTests {
    @Test func everyCharacterShowsOnceBeforeAnyRepeats() {
        var deck = CharacterDeck(random: { 0.3 })
        let round = (0..<Characters.all.count).map { _ in deck.next() }
        #expect(Set(round) == Set(Characters.all))
    }

    @Test func itReshufflesAfterAFullRound() {
        var deck = CharacterDeck(random: { 0.5 })
        for _ in Characters.all { _ = deck.next() }
        let second = (0..<Characters.all.count).map { _ in deck.next() }
        #expect(Set(second).count == Characters.all.count)
    }

    @Test func aRoundNeverOpensWithTheCharacterThatClosedTheLastOne() {
        for seed in 0..<50 {
            var s = Int64(seed + 1)
            // Park-Miller, the same generator the web app's test uses.
            var deck = CharacterDeck(random: {
                s = (s * 16807) % 2147483647
                return Double(s) / 2147483647
            })
            var last = ""
            for _ in 0..<(Characters.all.count * 3) {
                let c = deck.next()
                #expect(c != last)
                last = c
            }
        }
    }

    @Test func labelsCapitaliseTheFileName() {
        #expect(Characters.label("dad") == "Dad")
        #expect(Characters.label("mackenzie") == "Mackenzie")
        #expect(Characters.label("terriers") == "The Terriers")
    }
}
